import os
import time
import requests

WAZUH_API = os.environ.get('WAZUH_API','http://wazuh-manager:55000')
WAZUH_USER = os.environ.get('WAZUH_USER','wazuh')
WAZUH_PASS = os.environ.get('WAZUH_PASS','wazuh')
WAZUH_TOKEN = os.environ.get('WAZUH_TOKEN')
SHUFFLE_WEBHOOK = os.environ.get('SHUFFLE_WEBHOOK')
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL','10'))

# Small forwarder that polls Wazuh v4 API (/v4/alerts) and forwards to a Shuffle webhook.
# Supports basic auth or token auth via WAZUH_TOKEN.

last_ids = set()

def get_headers():
    headers = {'Content-Type':'application/json'}
    if WAZUH_TOKEN:
        headers['Authorization'] = f'Bearer {WAZUH_TOKEN}'
    return headers

while True:
    try:
        url = f"{WAZUH_API}/v4/alerts"
        auth = None if WAZUH_TOKEN else (WAZUH_USER, WAZUH_PASS)
        resp = requests.get(url, auth=auth, headers=get_headers(), timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            alerts = data.get('data', [])
            for alert in alerts:
                alert_id = alert.get('id') or alert.get('rule', {}).get('id')
                if not alert_id:
                    # Fallback to entire alert string hash
                    alert_id = str(hash(str(alert)))
                if alert_id in last_ids:
                    continue
                # Forward
                if SHUFFLE_WEBHOOK:
                    try:
                        requests.post(SHUFFLE_WEBHOOK, json=alert, timeout=10)
                    except Exception as e:
                        print('Error posting to Shuffle webhook', e)
                print('Forwarded alert', alert_id)
                last_ids.add(alert_id)
                # keep last_ids small
                if len(last_ids) > 1000:
                    # drop oldest roughly
                    last_ids = set(list(last_ids)[-500:])
        else:
            print('Wazuh API returned', resp.status_code, resp.text)
    except Exception as e:
        print('Error polling Wazuh API', e)
    time.sleep(POLL_INTERVAL)
