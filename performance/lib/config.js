function integerFromEnv(
    name,
    fallback,
    minimum = 0,
    maximum = Number.POSITIVE_INFINITY,
) {
    const rawValue = __ENV[name];
    if (rawValue === undefined || rawValue === null || rawValue === '') {
        return fallback;
    }

    const parsedValue = Number(rawValue);
    if (!Number.isInteger(parsedValue) || parsedValue < minimum || parsedValue > maximum) {
        throw new Error(`${name} must be an integer between ${minimum} and ${maximum}.`);
    }

    return parsedValue;
}

function numberFromEnv(name, fallback, minimum = 0, maximum = Number.POSITIVE_INFINITY) {
    const rawValue = __ENV[name];
    if (rawValue === undefined || rawValue === null || rawValue === '') {
        return fallback;
    }

    const parsedValue = Number(rawValue);
    if (!Number.isFinite(parsedValue) || parsedValue < minimum || parsedValue > maximum) {
        throw new Error(`${name} must be between ${minimum} and ${maximum}.`);
    }

    return parsedValue;
}

function optionalIdFromEnv(name) {
    const rawValue = __ENV[name];
    if (rawValue === undefined || rawValue === null || rawValue === '') {
        return null;
    }

    return integerFromEnv(name, null, 1);
}

function idListFromEnv(name, fallbackId = null) {
    const rawValue = __ENV[name];
    const values = rawValue === undefined || rawValue === null || rawValue.trim() === ''
        ? []
        : rawValue.split(',').map((value) => value.trim()).filter((value) => value.length > 0);

    const parsedValues = values.map((value) => {
        const parsedValue = Number(value);
        if (!Number.isInteger(parsedValue) || parsedValue < 1) {
            throw new Error(`${name} must contain only comma-separated positive integers.`);
        }
        return parsedValue;
    });

    if (fallbackId !== null) {
        parsedValues.push(fallbackId);
    }

    return Object.freeze(Array.from(new Set(parsedValues)));
}

function stringListFromEnv(...names) {
    const values = [];

    for (const name of names) {
        const rawValue = __ENV[name];
        if (rawValue === undefined || rawValue === null || rawValue.trim() === '') {
            continue;
        }

        values.push(
            ...rawValue
                .split(',')
                .map((value) => value.trim())
                .filter((value) => value.length > 0),
        );
    }

    return Object.freeze(Array.from(new Set(values)));
}

function credentialAccountsFromEnv(emailListName, passwordListName, email, password) {
    const rawEmails = __ENV[emailListName] || '';
    const rawPasswords = __ENV[passwordListName] || '';

    if (rawEmails === '' && rawPasswords === '') {
        return Object.freeze(email && password
            ? [Object.freeze({ email, password })]
            : []);
    }
    if (rawEmails === '' || rawPasswords === '') {
        throw new Error(`${emailListName} and ${passwordListName} must be provided together.`);
    }

    const emails = rawEmails.split(',').map((value) => value.trim());
    const passwords = rawPasswords.split(',').map((value) => value.trim());
    if (
        emails.length !== passwords.length
        || emails.some((value) => value === '')
        || passwords.some((value) => value === '')
    ) {
        throw new Error(`${emailListName} and ${passwordListName} must contain the same number of non-empty values.`);
    }

    return Object.freeze(emails.map((accountEmail, index) => Object.freeze({
        email: accountEmail,
        password: passwords[index],
    })));
}

function booleanFromEnv(name, fallback = false) {
    const rawValue = __ENV[name];
    if (rawValue === undefined || rawValue === null || rawValue === '') {
        return fallback;
    }

    if (rawValue === 'true') {
        return true;
    }
    if (rawValue === 'false') {
        return false;
    }

    throw new Error(`${name} must be either true or false.`);
}

function normalizeBaseUrl(value) {
    return value.replace(/\/+$/, '');
}

const baseUrl = normalizeBaseUrl(__ENV.BASE_URL || 'http://localhost:8080');
const equipmentId = optionalIdFromEnv('EQUIPMENT_ID');
const rentalId = optionalIdFromEnv('RENTAL_ID');
const paymentId = optionalIdFromEnv('PAYMENT_ID');
const reportId = optionalIdFromEnv('REPORT_ID');
const userId = optionalIdFromEnv('USER_ID');
const notificationId = optionalIdFromEnv('NOTIFICATION_ID');
const rentableEquipmentIds = idListFromEnv('RENTABLE_EQUIPMENT_IDS');
const configuredUserAccessToken = __ENV.USER_TOKEN || __ENV.K6_USER_TOKEN || '';
const configuredAdminAccessToken = __ENV.ADMIN_TOKEN || __ENV.K6_ADMIN_TOKEN || '';
const configuredUserTokens = stringListFromEnv('USER_TOKENS', 'K6_USER_TOKENS');
const configuredAdminTokens = stringListFromEnv('ADMIN_TOKENS', 'K6_ADMIN_TOKENS');
const userEmail = __ENV.USER_EMAIL || '';
const userPassword = __ENV.USER_PASSWORD || '';
const adminEmail = __ENV.ADMIN_EMAIL || '';
const adminPassword = __ENV.ADMIN_PASSWORD || '';
const userAccounts = credentialAccountsFromEnv(
    'USER_EMAILS',
    'USER_PASSWORDS',
    userEmail,
    userPassword,
);
const adminAccounts = credentialAccountsFromEnv(
    'ADMIN_EMAILS',
    'ADMIN_PASSWORDS',
    adminEmail,
    adminPassword,
);
const userTokens = configuredUserTokens.length > 0
    ? configuredUserTokens
    : Object.freeze(configuredUserAccessToken ? [configuredUserAccessToken] : []);
const adminTokens = configuredAdminTokens.length > 0
    ? configuredAdminTokens
    : Object.freeze(configuredAdminAccessToken ? [configuredAdminAccessToken] : []);

export const config = Object.freeze({
    baseUrl,
    credentials: Object.freeze({
        user: Object.freeze({
            email: userEmail || userAccounts[0]?.email || '',
            password: userPassword || userAccounts[0]?.password || '',
            accounts: userAccounts,
            accessToken: configuredUserAccessToken || userTokens[0] || '',
            tokens: userTokens,
        }),
        admin: Object.freeze({
            email: adminEmail || adminAccounts[0]?.email || '',
            password: adminPassword || adminAccounts[0]?.password || '',
            accounts: adminAccounts,
            accessToken: configuredAdminAccessToken || adminTokens[0] || '',
            tokens: adminTokens,
        }),
    }),
    ids: Object.freeze({
        equipmentId,
        rentalId,
        paymentId,
        reportId,
        userId,
        notificationId,
        equipmentIds: idListFromEnv('EQUIPMENT_IDS', equipmentId),
        rentalIds: idListFromEnv('RENTAL_IDS', rentalId),
        paymentIds: idListFromEnv('PAYMENT_IDS', paymentId),
        reportIds: idListFromEnv('REPORT_IDS', reportId),
        userIds: idListFromEnv('USER_IDS', userId),
        notificationIds: idListFromEnv('NOTIFICATION_IDS', notificationId),
        reportTargetIds: idListFromEnv('REPORT_TARGET_IDS'),
        rentableEquipmentIds,
        writeEquipmentIds: rentableEquipmentIds,
    }),
    paging: Object.freeze({
        page: integerFromEnv('PAGE', 0, 0),
        size: integerFromEnv('PAGE_SIZE', 20, 1, 100),
    }),
    requestTimeout: __ENV.REQUEST_TIMEOUT || '30s',
    thinkTimeSeconds: numberFromEnv('THINK_TIME_SECONDS', 0.2, 0),
    smoke: Object.freeze({
        vus: integerFromEnv('SMOKE_VUS', 1, 1),
        iterations: integerFromEnv('SMOKE_ITERATIONS', 1, 1),
    }),
    baseline: Object.freeze({
        endpoint: __ENV.BASELINE_ENDPOINT || 'equipment-list',
        startRate: integerFromEnv('START_RATE', 5, 1),
        targetRate: integerFromEnv('TARGET_RATE', 20, 1),
        rate: integerFromEnv('BASELINE_RATE', 10, 1),
        duration: __ENV.BASELINE_DURATION || '3m',
        preAllocatedVUs: integerFromEnv('BASELINE_PRE_ALLOCATED_VUS', 10, 1),
        maxVUs: integerFromEnv('BASELINE_MAX_VUS', 50, 1),
        allowMutating: booleanFromEnv(
            'ALLOW_MUTATING',
            booleanFromEnv('ALLOW_DESTRUCTIVE_WRITES', false),
        ),
    }),
    thresholds: Object.freeze({
        p95Ms: integerFromEnv('P95_MS', 1000, 1),
        errorRate: numberFromEnv('ERROR_RATE', 0.01, 0, 1),
        checkRate: numberFromEnv('CHECK_RATE', 0.99, 0, 1),
    }),
});

export function buildQuery(parameters = {}) {
    const pairs = [];

    for (const [key, value] of Object.entries(parameters)) {
        if (value === undefined || value === null || value === '') {
            continue;
        }

        const values = Array.isArray(value) ? value : [value];
        for (const item of values) {
            pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(item))}`);
        }
    }

    return pairs.length === 0 ? '' : `?${pairs.join('&')}`;
}

export function apiUrl(path, query) {
    const normalizedPath = path.startsWith('/') ? path : `/${path}`;
    return `${config.baseUrl}${normalizedPath}${buildQuery(query)}`;
}

export function requireEnv(name, value) {
    if (value === undefined || value === null || String(value).trim() === '') {
        throw new Error(`${name} environment variable is required for this scenario.`);
    }

    return value;
}
