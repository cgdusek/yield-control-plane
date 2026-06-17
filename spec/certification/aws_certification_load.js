import http from "k6/http";
import { check, sleep } from "k6";

const baseUrl = __ENV.API_BASE_URL || "http://localhost:8080";
const duration = __ENV.CERT_DURATION || "30m";
const vus = Number(__ENV.CERT_VUS || "25");
const targetAttempts = Number(__ENV.CERT_TARGET_ATTEMPTS || "1000");
const runId = __ENV.CERT_RUN_ID || `${Date.now()}`;
const ratePerMinute = Number(
  __ENV.CERT_RATE_PER_MINUTE || Math.max(1, Math.ceil(targetAttempts / durationMinutes(duration))),
);

http.setResponseCallback(http.expectedStatuses({ min: 200, max: 399 }, 409, 422));

export const options = {
  scenarios: {
    certification: {
      executor: "constant-arrival-rate",
      rate: ratePerMinute,
      timeUnit: "1m",
      duration,
      preAllocatedVUs: vus,
      maxVUs: vus,
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<1000"],
    checks: ["rate>0.95"],
    iterations: [`count>=${targetAttempts}`],
  },
};

function durationSeconds(value) {
  const match = /^(\d+)(s|m|h)$/.exec(value);
  if (!match) {
    return 30 * 60;
  }
  const amount = Number(match[1]);
  if (match[2] === "h") {
    return amount * 60 * 60;
  }
  if (match[2] === "m") {
    return amount * 60;
  }
  return amount;
}

function durationMinutes(value) {
  return Math.max(1, Math.ceil(durationSeconds(value) / 60));
}

function uuid(seed) {
  const suffix = `${seed}`.padStart(12, "0").slice(-12);
  return `33333333-3333-4333-8333-${suffix}`;
}

function headers(key, correlationId) {
  return {
    "Content-Type": "application/json",
    "Idempotency-Key": key,
    "Correlation-Id": correlationId,
  };
}

function post(path, key, correlationId, body) {
  return http.post(`${baseUrl}${path}`, JSON.stringify(body), {
    headers: headers(key, correlationId),
  });
}

export default function () {
  const attempt = (__VU - 1) * Math.ceil(targetAttempts / vus) + __ITER;
  const accountId = uuid(attempt % 10000);
  const correlationId = `aws-cert-${runId}-${__VU}-${__ITER}`;
  const orderKey = `aws-cert-order-${runId}-${__VU}-${__ITER}`;

  const policy = post("/sweep-policies", `policy-${runId}-${accountId}`, correlationId, {
    account_id: accountId,
    minimum_cash_balance: "100.00",
    target_product: "FYOXX",
  });
  check(policy, {
    "policy accepted": (response) => response.status === 200,
  });

  const orderBody = {
    account_id: accountId,
    amount: "250.00",
    cash_asset: attempt % 3 === 0 ? "FIDD" : "USD",
    product_asset: "FYOXX",
  };
  const order = post("/sweep-orders", orderKey, correlationId, orderBody);
  check(order, {
    "order accepted": (response) => response.status === 200,
  });

  const duplicate = post("/sweep-orders", orderKey, correlationId, orderBody);
  check(duplicate, {
    "duplicate idempotency replay accepted": (response) => response.status === 200,
  });

  if (attempt % 10 === 0) {
    const conflict = post("/sweep-orders", orderKey, correlationId, {
      ...orderBody,
      amount: "251.00",
    });
    check(conflict, {
      "conflicting idempotency replay rejected": (response) => response.status === 409,
    });
  }

  if (attempt % 20 === 0) {
    const fiddYield = post("/dev/attempt-fidd-yield", `fidd-${runId}-${attempt}`, correlationId, {
      account_id: accountId,
      amount: "1.00",
    });
    check(fiddYield, {
      "FIDD yield attempt rejected": (response) => response.status === 422,
    });
  }

  if (attempt % 50 === 0) {
    const enableMismatch = post(
      "/dev/failure-injections/reconciliation-mismatch",
      `mismatch-on-${runId}-${attempt}`,
      correlationId,
      { enabled: true },
    );
    check(enableMismatch, {
      "mismatch enabled": (response) => response.status === 200,
    });
    const disableMismatch = post(
      "/dev/failure-injections/reconciliation-mismatch",
      `mismatch-off-${runId}-${attempt}`,
      correlationId,
      { enabled: false },
    );
    check(disableMismatch, {
      "mismatch disabled": (response) => response.status === 200,
    });
  }

  if (order.status === 200 && attempt % 5 === 0) {
    const orderId = order.json("order_id");
    const redemption = post("/redemptions", `redemption-${orderId}`, correlationId, {
      order_id: orderId,
    });
    check(redemption, {
      "redemption request is handled": (response) =>
        response.status === 200 || response.status === 409,
    });
  }

  sleep(1);
}
