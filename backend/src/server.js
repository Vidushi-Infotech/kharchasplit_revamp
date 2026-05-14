import dotenv from 'dotenv';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';

import { testConnection, pool, getPoolMetrics } from './config/database.js';
import { initializeDatabase } from './config/initDatabase.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';
import { cache } from './services/cacheService.js';

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

// Security middleware
app.use(helmet());

// CORS
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
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

// Body parsing — 2MB covers profile images + receipt photos
// JSON.parse of 10MB blocks event loop for ~200ms; 2MB keeps it under ~40ms
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));

// Compression — skip responses under 1KB (overhead not worth it for small JSON)
app.use(compression({ threshold: 1024 }));

// Logging — 'tiny' is ~5x less CPU overhead than 'combined' (no user-agent, referrer parsing)
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan(process.env.NODE_ENV === 'production' ? 'tiny' : 'dev'));
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

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (error) => {
  console.error('Unhandled Rejection:', error);
  process.exit(1);
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
