import { fail } from 'k6';
import http from 'k6/http';
import { apiUrl, config, requireEnv } from './config.js';
import { expectAccessToken } from './checks.js';

export function requestLogin(credentials, label = 'user') {
    requireEnv(`${label.toUpperCase()}_EMAIL`, credentials?.email);
    requireEnv(`${label.toUpperCase()}_PASSWORD`, credentials?.password);

    return http.post(
        apiUrl('/api/v1/auth/login'),
        JSON.stringify({
            email: credentials.email,
            password: credentials.password,
        }),
        {
            headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
            },
            tags: {
                name: 'POST /api/v1/auth/login',
                auth_role: label,
            },
            timeout: config.requestTimeout,
        },
    );
}

export function login(credentials, label = 'user') {
    const response = requestLogin(credentials, label);
    const accessToken = expectAccessToken(response, `${label} login`);

    if (!accessToken) {
        fail(`${label} login failed; an access token was not issued.`);
    }

    return accessToken;
}

export function resolveAccessToken(credentials, label = 'user') {
    const suppliedToken = credentials?.accessToken || credentials?.tokens?.[0] || '';
    if (suppliedToken) {
        return suppliedToken;
    }

    return login(credentials, label);
}

export function authorizationHeaders(accessToken, extraHeaders = {}) {
    requireEnv('ACCESS_TOKEN', accessToken);

    return {
        Accept: 'application/json',
        Authorization: `Bearer ${accessToken}`,
        ...extraHeaders,
    };
}
