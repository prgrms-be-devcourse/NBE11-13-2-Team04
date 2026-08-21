import { fail, sleep } from 'k6';
import http from 'k6/http';
import { Trend } from 'k6/metrics';

import { authorizationHeaders, requestLogin } from '../lib/auth.js';
import { apiUrl, config } from '../lib/config.js';
import { expectAccessToken, expectStatus } from '../lib/checks.js';

const loginDuration = new Trend('auth_login_duration', true);
const csrfDuration = new Trend('auth_csrf_duration', true);
const refreshDuration = new Trend('auth_refresh_duration', true);
const logoutDuration = new Trend('auth_logout_duration', true);

export const options = {
    scenarios: {
        auth_session: {
            executor: 'constant-vus',
            vus: Number(__ENV.AUTH_SESSION_VUS || 5),
            duration: __ENV.AUTH_SESSION_DURATION || '3m',
            gracefulStop: '30s',
            tags: { test_type: 'auth-session' },
        },
    },
    thresholds: {
        checks: [`rate>${config.thresholds.checkRate}`],
        http_req_failed: [`rate<${config.thresholds.errorRate}`],
        auth_login_duration: [`p(95)<${Number(__ENV.AUTH_LOGIN_P95_MS || 500)}`],
        auth_refresh_duration: [`p(95)<${Number(__ENV.AUTH_REFRESH_P95_MS || 500)}`],
        auth_logout_duration: [`p(95)<${Number(__ENV.AUTH_LOGOUT_P95_MS || 500)}`],
        dropped_iterations: ['count==0'],
    },
};

export function setup() {
    if (!config.credentials.user.accounts || config.credentials.user.accounts.length === 0) {
        fail('USER_EMAIL/USER_PASSWORD or USER_EMAILS/USER_PASSWORDS is required.');
    }
    return {};
}

function accountForVu() {
    const accounts = config.credentials.user.accounts;
    return accounts[Math.max(0, __VU - 1) % accounts.length];
}

function csrfTokenFromCookie() {
    const cookies = http.cookieJar().cookiesForURL(config.baseUrl);
    const tokens = cookies['XSRF-TOKEN'];
    return tokens && tokens.length > 0 ? tokens[0] : null;
}

export default function () {
    const loginResponse = requestLogin(accountForVu(), `auth-session-user-${__VU}`);
    loginDuration.add(loginResponse.timings.duration);
    expectStatus(loginResponse, 200, 'auth session login');
    let accessToken = expectAccessToken(loginResponse, 'auth session login');
    if (!accessToken) {
        fail('Login did not issue an access token.');
    }

    const csrfResponse = http.get(apiUrl('/api/v1/auth/csrf'), {
        headers: { Accept: 'application/json' },
        tags: { name: 'GET /api/v1/auth/csrf' },
        timeout: config.requestTimeout,
    });
    csrfDuration.add(csrfResponse.timings.duration);
    expectStatus(csrfResponse, 204, 'csrf token issue');

    const csrfToken = csrfTokenFromCookie();
    if (!csrfToken) {
        fail('XSRF-TOKEN cookie was not issued.');
    }

    const refreshResponse = http.post(apiUrl('/api/v1/auth/refresh'), null, {
        headers: {
            Accept: 'application/json',
            'X-XSRF-TOKEN': csrfToken,
        },
        tags: { name: 'POST /api/v1/auth/refresh' },
        timeout: config.requestTimeout,
    });
    refreshDuration.add(refreshResponse.timings.duration);
    expectStatus(refreshResponse, 200, 'refresh token rotation');
    accessToken = expectAccessToken(refreshResponse, 'refresh token rotation');
    if (!accessToken) {
        fail('Refresh did not issue an access token.');
    }

    const logoutResponse = http.post(apiUrl('/api/v1/auth/logout'), null, {
        headers: authorizationHeaders(accessToken, {
            'X-XSRF-TOKEN': csrfToken,
        }),
        tags: { name: 'POST /api/v1/auth/logout' },
        timeout: config.requestTimeout,
    });
    logoutDuration.add(logoutResponse.timings.duration);
    expectStatus(logoutResponse, 204, 'auth session logout');

    sleep(config.thinkTimeSeconds);
}
