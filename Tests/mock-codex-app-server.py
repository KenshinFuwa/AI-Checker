#!/usr/bin/env python3
"""Fake JSONL Codex app-server; no network, credentials or real accounts."""
import json
import os
import sys
from time import time

assert len(sys.argv) >= 2 and sys.argv[1] == 'app-server'
assert '/AI Checker/CodexAccounts/' in os.environ.get('CODEX_HOME', '')
assert 'OPENAI_API_KEY' not in os.environ
logged_in = False
for line in sys.stdin:
    msg = json.loads(line)
    req_id = msg.get('id')
    method = msg.get('method')
    if req_id is None:
        continue
    if method == 'initialize':
        result = {'userAgent': 'fixture'}
    elif method == 'account/read':
        result = {'account': {'type': 'chatgpt', 'email': 'mock@example.invalid'} if logged_in else None,
                  'requiresOpenaiAuth': True}
    elif method == 'account/login/start':
        assert msg.get('params', {}).get('type') == 'chatgpt'
        logged_in = True
        result = {'type': 'chatgpt', 'loginId': 'fake', 'authUrl': 'https://chatgpt.com/mock-login'}
    elif method == 'account/rateLimits/read':
        reset = int(time()) + 7200
        result = {'rateLimitsByLimitId': {'codex': {'primary': {'usedPercent': 10, 'windowDurationMins': 300, 'resetsAt': reset},
                                                     'secondary': {'usedPercent': 20, 'windowDurationMins': 10080, 'resetsAt': reset}}}}
    elif method == 'account/logout':
        logged_in = False
        result = {}
    else:
        result = {}
    print(json.dumps({'id': req_id, 'result': result}), flush=True)
    if method == 'account/login/start':
        print(json.dumps({'method': 'account/login/completed', 'params': {'loginId': 'fake', 'success': True}}), flush=True)
