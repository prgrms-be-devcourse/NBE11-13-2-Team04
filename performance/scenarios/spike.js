import { config } from '../lib/config.js';
import { prepareMixedLoad, runMixedIteration } from './mixed-load.js';

const baselineRate = Number(__ENV.SPIKE_BASELINE_RATE || config.baseline.targetRate || 10);
const spikeRate = Number(__ENV.SPIKE_RATE || 100);

export const options = {
    scenarios: {
        spike_load: {
            executor: 'ramping-arrival-rate',
            startRate: baselineRate,
            timeUnit: '1s',
            preAllocatedVUs: Number(__ENV.PRE_ALLOCATED_VUS || config.baseline.preAllocatedVUs || 100),
            maxVUs: Number(__ENV.MAX_VUS || config.baseline.maxVUs || 500),
            stages: [
                { target: baselineRate, duration: __ENV.SPIKE_WARMUP_DURATION || '1m' },
                { target: spikeRate, duration: __ENV.SPIKE_RAMP_DURATION || '10s' },
                { target: spikeRate, duration: __ENV.SPIKE_HOLD_DURATION || '30s' },
                { target: baselineRate, duration: __ENV.SPIKE_FALL_DURATION || '10s' },
                { target: baselineRate, duration: __ENV.SPIKE_RECOVERY_DURATION || '2m' },
                { target: 0, duration: '10s' },
            ],
            gracefulStop: '30s',
            tags: { test_type: 'spike' },
        },
    },
    thresholds: {
        checks: ['rate>0.95'],
        http_req_failed: ['rate<0.05'],
        http_req_duration: [
            `p(95)<${Number(__ENV.SPIKE_P95_MS || 1500)}`,
            `p(99)<${Number(__ENV.SPIKE_P99_MS || 3000)}`,
        ],
        unexpected_responses: ['count==0'],
        dropped_iterations: ['count==0'],
    },
};

export function setup() {
    return prepareMixedLoad();
}

export default function (data) {
    runMixedIteration(data);
}
