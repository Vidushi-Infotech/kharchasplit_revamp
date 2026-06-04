import dotenv from 'dotenv';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import pinoHttp from 'pino-http';
import { monitorEventLoopDelay } from 'perf_hooks';

import { testConnection, pool, getPoolMetrics } from './config/database.js';
import { initializeDatabase } from './config/initDatabase.js';
import { initFirebase } from './config/firebaseAdmin.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';
import { cache } from './services/cacheService.js';
import { logger } from './utils/logger.js';

// Import routes
import authRoutes from './routes/authRoutes.js';
import userRoutes from './routes/userRoutes.js';
import groupRoutes from './routes/groupRoutes.js';
import expenseRoutes from './routes/expenseRoutes.js';
import settlementRoutes from './routes/settlementRoutes.js';
import personalExpenseRoutes from './routes/personalExpenseRoutes.js';
import syncRoutes from './routes/syncRoutes.js';
import activityRoutes from './routes/activityRoutes.js';
import inviteRoutes from './routes/inviteRoutes.js';
import policiesRoutes from './routes/policiesRoutes.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Trust the first proxy (Cloudflare / nginx / Render / Heroku) so
// req.secure + x-forwarded-* headers reflect the real client connection.
if (process.env.NODE_ENV === 'production') {
  app.set('trust proxy', 1);
}

// Security middleware
app.use(helmet());

// Force HTTPS + HSTS in production. Any plaintext request is upgraded with
// a 308 (preserving method + body). HSTS instructs compliant browsers to
// refuse plaintext for one year, including subdomains.
if (process.env.NODE_ENV === 'production') {
  app.use((req, res, next) => {
    if (req.secure || req.get('x-forwarded-proto') === 'https') return next();
    return res.redirect(308, `https://${req.get('host')}${req.originalUrl}`);
  });
  app.use(helmet.hsts({
    maxAge: 31536000,        // 1 year
    includeSubDomains: true,
    preload: true,
  }));
}

// CORS — explicit allow-list. Set CORS_ORIGIN to a comma-separated list
// of trusted origins (e.g. "https://app.kharchasplit.com,https://web.kharchasplit.com").
// Special value '*' is permitted ONLY when NODE_ENV !== 'production' so that
// emulators / local web builds work; rejected outright in production.
const rawCors = (process.env.CORS_ORIGIN || '').trim();
let corsOrigin;
if (rawCors === '*' || rawCors === '') {
  if (process.env.NODE_ENV === 'production') {
    console.error(
      '[CORS] CORS_ORIGIN must be a non-empty allow-list in production. ' +
      "Refusing to start with '*' or empty value."
    );
    process.exit(1);
  }
  corsOrigin = true; // reflect request origin in dev
} else {
  corsOrigin = rawCors.split(',').map((s) => s.trim()).filter(Boolean);
}
app.use(cors({
  origin: corsOrigin,
  credentials: true,
}));

// Rate limiting - more permissive for mobile app usage patterns
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 1 * 60 * 1000, // 1 minute window
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 200, // 200 requests per minute
  message: {
    success: false,
    error: 'Too many requests, please try again later',
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});
app.use('/api', limiter);

// Body parsing — keep the global limit small (256KB covers any sane JSON
// or form payload). The handful of endpoints that genuinely need ~10MB
// for inline base64 receipts / cover / profile photos opt in via their
// own route-level `express.json({ limit: '10mb' })` middleware (see
// expenseRoutes, groupRoutes, userRoutes). Trade-off avoided: a global
// 10MB limit meant any endpoint — including bare /auth/login — could
// be hit with a 10MB body and tie up the event loop for ~200ms.
app.use(express.json({ limit: '256kb' }));
app.use(express.urlencoded({ extended: true, limit: '256kb' }));

// Compression — skip responses under 1KB (overhead not worth it for small JSON)
app.use(compression({ threshold: 1024 }));

// Structured request logging via pino-http. Replaces morgan; logger.js
// handles redaction (Authorization headers, OTPs, tokens, base64 blobs).
// Skip noisy /health pings to keep logs focused.
if (process.env.NODE_ENV !== 'test') {
  app.use(pinoHttp({
    logger,
    autoLogging: {
      ignore: (req) => req.url === '/health',
    },
    customLogLevel: (req, res, err) => {
      if (err || res.statusCode >= 500) return 'error';
      if (res.statusCode >= 400) return 'warn';
      return 'info';
    },
  }));
}

// Health check — includes pool + cache metrics for monitoring
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'KharchaSplit API is running',
    version: process.env.API_VERSION || 'v1',
    timestamp: new Date().toISOString(),
    pool: getPoolMetrics(),
    cache: cache.getStats(),
  });
});

// API routes
const API_VERSION = process.env.API_VERSION || 'v1';
app.use(`/api/${API_VERSION}/auth`, authRoutes);
app.use(`/api/${API_VERSION}/users`, userRoutes);
app.use(`/api/${API_VERSION}/groups`, groupRoutes);
app.use(`/api/${API_VERSION}/expenses`, expenseRoutes);
app.use(`/api/${API_VERSION}/settlements`, settlementRoutes);
app.use(`/api/${API_VERSION}/personal-expenses`, personalExpenseRoutes);
app.use(`/api/${API_VERSION}/sync`, syncRoutes);
app.use(`/api/${API_VERSION}/activities`, activityRoutes);
app.use(`/api/${API_VERSION}/invites`, inviteRoutes);
app.use(`/api/${API_VERSION}/policies`, policiesRoutes);

// 404 handler
app.use(notFound);

// Error handler
app.use(errorHandler);

// Start server
let server;

const startServer = async () => {
  try {
    // Test database connection
    const dbConnected = await testConnection();

    if (!dbConnected) {
      console.error('Failed to connect to database. Exiting...');
      process.exit(1);
    }

    // Initialize database schema (create tables/columns if not exist)
    const dbInitialized = await initializeDatabase();
    if (!dbInitialized) {
      console.error('Failed to initialize database schema. Exiting...');
      process.exit(1);
    }

    // Initialize Firebase Admin (push notifications). Non-fatal if missing.
    await initFirebase();

    // Event loop lag monitor. Posts a warn line every 30s if the max
    // observed lag in the window crossed 100ms — i.e. some synchronous
    // hot block ran long enough to push real requests behind it.
    // Cheap to run (sampling at 20ms resolution from a native histogram)
    // and disabled-by-flag for CI.
    if (process.env.EVENT_LOOP_MONITOR !== 'false') {
      const eld = monitorEventLoopDelay({ resolution: 20 });
      eld.enable();
      const LAG_THRESHOLD_MS = parseInt(process.env.EVENT_LOOP_LAG_WARN_MS) || 100;
      const intervalHandle = setInterval(() => {
        const maxMs = eld.max / 1e6;
        const p99Ms = eld.percentile(99) / 1e6;
        if (maxMs > LAG_THRESHOLD_MS) {
          logger.warn(
            { maxMs: +maxMs.toFixed(0), p99Ms: +p99Ms.toFixed(0) },
            '[loop] event loop lag spike',
          );
        }
        eld.reset();
      }, 30_000);
      // Don't keep the process alive if it's otherwise idle.
      intervalHandle.unref();
    }

    server = app.listen(PORT, () => {
      console.log('');
      console.log('╔════════════════════════════════════════╗');
      console.log('║   🚀 KharchaSplit API Server          ║');
      console.log('╚════════════════════════════════════════╝');
      console.log('');
      console.log(`✅ Server running on port ${PORT}`);
      console.log(`✅ Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`✅ API Version: ${API_VERSION}`);
      console.log('');
      console.log(`📡 Health check: http://localhost:${PORT}/health`);
      console.log(`📚 API Base URL: http://localhost:${PORT}/api/${API_VERSION}`);
      console.log('');
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

// Handle uncaught exceptions — structured + flush logger before exit so
// the error actually reaches the platform's log collector.
process.on('uncaughtException', (error) => {
  logger.fatal({ err: error }, 'Uncaught exception');
  // Give the logger one tick to flush, then die.
  setImmediate(() => process.exit(1));
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (error) => {
  logger.fatal({ err: error }, 'Unhandled rejection');
  setImmediate(() => process.exit(1));
});

// Graceful shutdown — drain in-flight requests then close DB pool
const gracefulShutdown = (signal) => {
  console.log(`${signal} received. Shutting down gracefully...`);
  if (server) {
    server.close(async () => {
      console.log('HTTP server closed');
      try {
        await pool.end();
        console.log('Database pool closed');
      } catch (err) {
        console.error('Error closing pool:', err);
      }
      process.exit(0);
    });
    // Force exit after 10s if connections won't drain
    setTimeout(() => {
      console.error('Forced shutdown after timeout');
      process.exit(1);
    }, 10000);
  } else {
    process.exit(0);
  }
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

startServer();

export default app;
