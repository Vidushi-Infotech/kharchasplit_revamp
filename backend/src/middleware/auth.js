import jwt from 'jsonwebtoken';
import { query  } from '../config/database.js';
import { cache, TTL } from '../services/cacheService.js';

/**
 * Middleware to verify JWT token
 */
const authenticate = async (req, res, next) => {
  try {
    // Get token from header
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'No token provided',
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Check cache first — this runs on EVERY authenticated request
    const cacheKey = `auth:user:${decoded.userId}`;
    const user = await cache.getOrSet(cacheKey, TTL.AUTH_USER, async () => {
      const result = await query(
        'SELECT id, phone_number, name, email FROM users WHERE id = $1 AND deleted_at IS NULL',
        [decoded.userId]
      );
      return result.rows[0] || null;
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid token - user not found',
      });
    }

    // Attach user to request
    req.user = {
      id: user.id,
      phone_number: user.phone_number,
      name: user.name,
      email: user.email,
    };

    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        error: 'Invalid token',
      });
    }

    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Token expired',
      });
    }

    console.error('Authentication error:', error);
    return res.status(500).json({
      success: false,
      error: 'Authentication failed',
    });
  }
};

/**
 * Optional authentication - adds user if token is valid, but doesn't fail if not
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const cacheKey = `auth:user:${decoded.userId}`;
    const user = await cache.getOrSet(cacheKey, TTL.AUTH_USER, async () => {
      const result = await query(
        'SELECT id, phone_number, name, email FROM users WHERE id = $1 AND deleted_at IS NULL',
        [decoded.userId]
      );
      return result.rows[0] || null;
    });

    if (user) {
      req.user = user;
    }

    next();
  } catch (error) {
    // Silently fail - just don't add user
    next();
  }
};

export {
  authenticate,
  optionalAuth,
};
