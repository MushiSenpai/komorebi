#!/usr/bin/env python3
"""Creates/updates the Arena `scores` collection on a PocketBase instance.

Usage: setup_collection.py <base_url> <credentials_file>

The credentials file holds `email=...` and `password=...` lines (written by
deploy.sh). Rules: anyone may submit or read scores; nobody may edit or
delete them (admins excepted). A create rule caps believable scores.
"""
import json
import sys
import urllib.request

base, cred_path = sys.argv[1], sys.argv[2]
creds = dict(
    line.strip().split('=', 1)
    for line in open(cred_path)
    if '=' in line
)


def call(path, payload=None, token=None, method=None):
    req = urllib.request.Request(
        base + path,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={
            'Content-Type': 'application/json',
            **({'Authorization': token} if token else {}),
        },
        method=method or ('POST' if payload is not None else 'GET'),
    )
    try:
        with urllib.request.urlopen(req) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode()
        raise SystemExit(f'{path} -> {error.code}: {body}')


auth = call('/api/collections/_superusers/auth-with-password',
            {'identity': creds['email'], 'password': creds['password']})
token = auth['token']

schema = {
    'name': 'scores',
    'type': 'base',
    'fields': [
        {'name': 'handle', 'type': 'text', 'required': True, 'max': 24},
        {'name': 'client_id', 'type': 'text', 'required': True, 'max': 40},
        {'name': 'mode', 'type': 'text', 'required': True, 'max': 24},
        {'name': 'score', 'type': 'number', 'required': True},
        {'name': 'pieces', 'type': 'number'},
        {'name': 'duration', 'type': 'number'},
        {'name': 'played_at', 'type': 'date'},
    ],
    # Anyone may submit (sanity-capped) and read; nothing is editable.
    'createRule': '@request.body.score >= 0 && @request.body.score <= 500',
    'listRule': '',
    'viewRule': '',
    'updateRule': None,
    'deleteRule': None,
}

existing = [
    c for c in call('/api/collections?perPage=200', token=token)['items']
    if c['name'] == 'scores'
]
if existing:
    call(f"/api/collections/{existing[0]['id']}", schema, token=token,
         method='PATCH')
    print('   scores collection updated')
else:
    call('/api/collections', schema, token=token)
    print('   scores collection created')
