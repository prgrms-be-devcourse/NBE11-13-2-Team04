import { config } from '../lib/config.js';
import {
    assertRenewableAuth,
    prepareMixedLoad,
    runMixedIteration,
} from './mixed-load.js';

const soakRate = Number(__ENV.SOAK_RATE || config.baseline.targetRate || 20);

export const options = {
    scenarios: {
        soak_load: {
            executor: 'constant-arrival-rate',
            rate: soakRate,
            timeUnit: '1s',
            duration: __ENV.SOAK_DURATION || '1h',
            preAllocatedVUs: Number(__ENV.PRE_ALLOCATED_VUS || config.baseline.preAllocatedVUs || 50),
            maxVUs: Number(__ENV.MAX_VUS || config.baseline.maxVUs || 200),
            gracefulStop: '1m',
            tags: { test_type: 'soak' },
        },
    },
    thresholds: {
        checks: ['rate>0.99'],
        http_req_failed: ['rate<0.01'],
        http_req_duration: [
            `p(95)<${Number(__ENV.SOAK_P95_MS || 750)}`,
            `p(99)<${Number(__ENV.SOAK_P99_MS || 1500)}`,
        ],
        unexpected_responses: ['count==0'],
        dropped_iterations: ['count==0'],
    },
};

export function setup() {
    assertRenewableAuth();
    return prepareMixedLoad({ preferLogin: true });
}

export default function (data) {
    runMixedIteration(data);
}
