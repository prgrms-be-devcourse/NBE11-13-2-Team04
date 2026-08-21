import { config } from '../lib/config.js';
import {
    assertRenewableAuth,
    prepareMixedLoad,
    runMixedIteration,
} from './mixed-load.js';

const startRate = Number(__ENV.STRESS_START_RATE || config.baseline.targetRate || 10);
const levelOne = Number(__ENV.STRESS_RATE_1 || 20);
const levelTwo = Number(__ENV.STRESS_RATE_2 || 40);
const levelThree = Number(__ENV.STRESS_RATE_3 || 80);
const levelFour = Number(__ENV.STRESS_RATE_4 || 120);

export const options = {
    scenarios: {
        stress_load: {
            executor: 'ramping-arrival-rate',
            startRate,
            timeUnit: '1s',
            preAllocatedVUs: Number(__ENV.PRE_ALLOCATED_VUS || config.baseline.preAllocatedVUs || 100),
            maxVUs: Number(__ENV.MAX_VUS || config.baseline.maxVUs || 500),
            stages: [
                { target: levelOne, duration: __ENV.STRESS_RAMP_DURATION || '2m' },
                { target: levelOne, duration: __ENV.STRESS_LEVEL_DURATION || '3m' },
                { target: levelTwo, duration: __ENV.STRESS_RAMP_DURATION || '2m' },
                { target: levelTwo, duration: __ENV.STRESS_LEVEL_DURATION || '3m' },
                { target: levelThree, duration: __ENV.STRESS_RAMP_DURATION || '2m' },
                { target: levelThree, duration: __ENV.STRESS_LEVEL_DURATION || '3m' },
                { target: levelFour, duration: __ENV.STRESS_RAMP_DURATION || '2m' },
                { target: levelFour, duration: __ENV.STRESS_LEVEL_DURATION || '3m' },
                { target: 0, duration: __ENV.STRESS_RECOVERY_DURATION || '2m' },
            ],
            gracefulStop: '30s',
            tags: { test_type: 'stress' },
        },
    },
    thresholds: {
        checks: ['rate>0.95'],
        http_req_failed: ['rate<0.05'],
        http_req_duration: [`p(95)<${Number(__ENV.STRESS_P95_MS || 2000)}`],
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
