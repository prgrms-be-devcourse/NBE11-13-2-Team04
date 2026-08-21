import http from 'k6/http';

import { apiUrl, config, requireEnv } from '../lib/config.js';
import {
    futureDate,
    jsonParams,
    prepareMixedLoad,
    recordMutation,
} from './mixed-load.js';

const concurrencyCase = String(__ENV.CONCURRENCY_CASE || 'report-duplicate').toLowerCase();
const concurrencyVUs = Math.max(2, Number(__ENV.CONCURRENCY_VUS || 50));
const destructiveWritesEnabled = String(__ENV.ALLOW_DESTRUCTIVE_WRITES || '').toLowerCase() === 'true';

export const options = {
    scenarios: {
        concurrent_mutation: {
            executor: 'per-vu-iterations',
            vus: concurrencyVUs,
            iterations: 1,
            maxDuration: __ENV.CONCURRENCY_MAX_DURATION || '1m',
            gracefulStop: '0s',
            tags: {
                test_type: 'concurrency',
                concurrency_case: concurrencyCase,
            },
        },
    },
    thresholds: {
        checks: ['rate==1'],
        http_req_failed: ['rate==0'],
        successful_mutations: ['count==1'],
        expected_conflicts: [`count==${concurrencyVUs - 1}`],
        unexpected_responses: ['count==0'],
    },
};

function configuredValue(...names) {
    for (const name of names) {
        const value = config.ids && config.ids[name];
        if (Array.isArray(value)) {
            if (value.length > 0) {
                return value[0];
            }
            continue;
        }
        if (value !== undefined && value !== null && value !== '') {
            return value;
        }
    }
    return null;
}

function required(name, value) {
    return value || requireEnv(name, value);
}

function prepareTarget(auth) {
    const actorToken = __ENV.OWNER_TOKEN || __ENV.RENTER_TOKEN || auth.userToken;
    const adminToken = __ENV.CONCURRENCY_ADMIN_TOKEN || auth.adminToken;

    switch (concurrencyCase) {
        case 'report-duplicate':
            return {
                actorToken: required('USER_TOKEN or USER_EMAIL/USER_PASSWORD', auth.userToken),
                targetType: __ENV.CONCURRENCY_TARGET_TYPE || __ENV.REPORT_TARGET_TYPE || 'EQUIPMENT',
                targetId: required(
                    'CONCURRENCY_TARGET_ID',
                    __ENV.CONCURRENCY_TARGET_ID || configuredValue('reportTargetIds', 'equipmentIds', 'equipment'),
                ),
            };
        case 'return-confirmation':
            return {
                actorToken: required('OWNER_TOKEN or USER_TOKEN', actorToken),
                rentalId: required(
                    'CONCURRENCY_RENTAL_ID',
                    __ENV.CONCURRENCY_RENTAL_ID
                        || configuredValue('returnableRentalIds', 'returnedRentalIds', 'rentalIds'),
                ),
            };
        case 'rental-approval':
            return {
                actorToken: required('OWNER_TOKEN or USER_TOKEN', actorToken),
                rentalId: required(
                    'CONCURRENCY_RENTAL_ID',
                    __ENV.CONCURRENCY_RENTAL_ID
                        || configuredValue('requestedRentalIds', 'approvableRentalIds', 'rentalIds'),
                ),
            };
        case 'rental-create':
        case 'rental-create-overlap':
            return {
                actorToken: required('RENTER_TOKEN or USER_TOKEN', __ENV.RENTER_TOKEN || auth.userToken),
                equipmentId: required(
                    'CONCURRENCY_EQUIPMENT_ID',
                    __ENV.CONCURRENCY_EQUIPMENT_ID
                        || configuredValue('rentableEquipmentIds', 'writeEquipmentIds', 'equipmentIds'),
                ),
            };
        case 'admin-user-status':
            return {
                actorToken: required('ADMIN_TOKEN or ADMIN_EMAIL/ADMIN_PASSWORD', adminToken),
                userId: required(
                    'CONCURRENCY_USER_ID',
                    __ENV.CONCURRENCY_USER_ID || configuredValue('userIds', 'userId'),
                ),
            };
        case 'admin-equipment-status':
            return {
                actorToken: required('ADMIN_TOKEN or ADMIN_EMAIL/ADMIN_PASSWORD', adminToken),
                equipmentId: required(
                    'CONCURRENCY_EQUIPMENT_ID',
                    __ENV.CONCURRENCY_EQUIPMENT_ID || configuredValue('equipmentIds', 'equipmentId'),
                ),
            };
        case 'admin-report-status':
            return {
                actorToken: required('ADMIN_TOKEN or ADMIN_EMAIL/ADMIN_PASSWORD', adminToken),
                reportId: required(
                    'CONCURRENCY_REPORT_ID',
                    __ENV.CONCURRENCY_REPORT_ID || configuredValue('reportIds', 'reportId'),
                ),
            };
        default:
            throw new Error(
                `Unsupported CONCURRENCY_CASE=${concurrencyCase}. `
                + 'Use report-duplicate, rental-create-overlap, return-confirmation, rental-approval, '
                + 'admin-user-status, admin-equipment-status, or admin-report-status.',
            );
    }
}

export function setup() {
    if (!destructiveWritesEnabled) {
        requireEnv('ALLOW_DESTRUCTIVE_WRITES=true', null);
    }

    const adminOnlyCase = concurrencyCase.startsWith('admin-');
    const auth = prepareMixedLoad({ requireUser: !adminOnlyCase });
    return {
        concurrencyCase,
        target: prepareTarget(auth),
    };
}

function createDuplicateReport(target) {
    const body = JSON.stringify({
        targetType: target.targetType,
        targetId: Number(target.targetId),
        reason: '동시성 부하 테스트',
        description: '동일 신고자와 동일 대상의 처리 중 신고는 한 건만 허용되어야 합니다.',
    });

    const response = http.post(
        apiUrl('/api/v1/reports'),
        body,
        jsonParams(target.actorToken, 'POST /api/v1/reports [concurrent]', true),
    );
    recordMutation(response, [201], 'concurrent-report');
}

function confirmReturn(target) {
    const hasIssue = String(__ENV.RETURN_HAS_ISSUE || 'false').toLowerCase() === 'true';
    const body = JSON.stringify({
        hasIssue,
        disputeReason: hasIssue ? '동시성 테스트 이상 반납' : null,
        disputeDescription: hasIssue ? '동일 반납 거래에는 최종 상태 전이가 한 번만 발생해야 합니다.' : null,
    });

    const response = http.post(
        apiUrl(`/api/v1/rentals/${target.rentalId}/return-confirmation`),
        body,
        jsonParams(target.actorToken, 'POST /api/v1/rentals/:id/return-confirmation [concurrent]', true),
    );
    recordMutation(response, [200], 'concurrent-return-confirmation');
}

function approveRental(target) {
    const response = http.patch(
        apiUrl(`/api/v1/rentals/${target.rentalId}/approve`),
        null,
        jsonParams(target.actorToken, 'PATCH /api/v1/rentals/:id/approve [concurrent]', true),
    );
    recordMutation(response, [200], 'concurrent-rental-approval');
}

function createRental(target) {
    const body = JSON.stringify({
        equipmentId: Number(target.equipmentId),
        startDate: futureDate(Number(__ENV.RENTAL_START_OFFSET_DAYS || 30)),
        endDate: futureDate(Number(__ENV.RENTAL_END_OFFSET_DAYS || 33)),
        receiverName: '동시성테스트',
        receiverPhone: '010-1234-5678',
        zipcode: '06236',
        address: '서울특별시 강남구 테헤란로',
        detailAddress: '동일 기간 예약 경합',
        requestMessage: '동일 장비와 동일 기간에는 하나의 대여 요청만 생성되어야 합니다.',
        useDefaultAddress: false,
    });

    const response = http.post(
        apiUrl('/api/v1/rentals'),
        body,
        jsonParams(target.actorToken, 'POST /api/v1/rentals [concurrent]', true),
    );
    recordMutation(response, [201], 'concurrent-rental-create');
}

function suspendUser(target) {
    const response = http.patch(
        apiUrl(`/api/v1/admin/users/${target.userId}/status`),
        JSON.stringify({
            status: 'SUSPENDED',
            reason: '동일 회원 관리자 상태 변경 동시성 테스트',
        }),
        jsonParams(target.actorToken, 'PATCH /api/v1/admin/users/:id/status [concurrent]', true),
    );
    recordMutation(response, [200], 'concurrent-admin-user-status');
}

function suspendEquipment(target) {
    const response = http.patch(
        apiUrl(`/api/v1/admin/equipment/${target.equipmentId}/status`),
        JSON.stringify({
            status: 'SUSPENDED',
            reason: '동일 장비 관리자 상태 변경 동시성 테스트',
        }),
        jsonParams(target.actorToken, 'PATCH /api/v1/admin/equipment/:id/status [concurrent]', true),
    );
    recordMutation(response, [200], 'concurrent-admin-equipment-status');
}

function startReportReview(target) {
    const response = http.patch(
        apiUrl(`/api/v1/admin/reports/${target.reportId}/status`),
        JSON.stringify({
            status: 'UNDER_REVIEW',
            adminMemo: '동일 신고 관리자 상태 변경 동시성 테스트',
        }),
        jsonParams(target.actorToken, 'PATCH /api/v1/admin/reports/:id/status [concurrent]', true),
    );
    recordMutation(response, [200], 'concurrent-admin-report-status');
}

export default function (data) {
    switch (data.concurrencyCase) {
        case 'report-duplicate':
            createDuplicateReport(data.target);
            break;
        case 'return-confirmation':
            confirmReturn(data.target);
            break;
        case 'rental-approval':
            approveRental(data.target);
            break;
        case 'rental-create':
        case 'rental-create-overlap':
            createRental(data.target);
            break;
        case 'admin-user-status':
            suspendUser(data.target);
            break;
        case 'admin-equipment-status':
            suspendEquipment(data.target);
            break;
        case 'admin-report-status':
            startReportReview(data.target);
            break;
        default:
            throw new Error(`Unsupported concurrency case: ${data.concurrencyCase}`);
    }
}
