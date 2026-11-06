import { query  } from '../config/database.js';

/**
 * Bulk sync operation
 * POST /api/v1/sync
 */
const syncData = async (req, res, next) => {
  try {
    const { operations } = req.body;

    if (!operations || !Array.isArray(operations)) {
      return res.status(400).json({
        success: false,
        error: 'operations array is required',
      });
    }

    const results = [];
    const errors = [];

    // Process ops in parallel with bounded concurrency. Each op writes
    // to its own row (separate recordId), so they're independent — the
    // old for-of `await` chain serialized them at the cost of total
    // latency = sum of per-op latency. A small concurrency cap keeps us
    // from saturating the pool when a client sends a huge batch.
    const CONCURRENCY = 4;
    const processOperation = async (operation) => {
      try {
        const { type, table, data, recordId } = operation;
        let result;
        switch (type) {
          case 'CREATE':
            result = await handleCreate(table, data, req.user.id);
            return { kind: 'ok', recordId, success: true, id: result.id };
          case 'UPDATE':
            await handleUpdate(table, recordId, data, req.user.id);
            return { kind: 'ok', recordId, success: true };
          case 'DELETE':
            await handleDelete(table, recordId, req.user.id);
            return { kind: 'ok', recordId, success: true };
          default:
            return {
              kind: 'err',
              recordId,
              error: 'Invalid operation type',
            };
        }
      } catch (error) {
        return {
          kind: 'err',
          recordId: operation.recordId,
          error: error.message,
        };
      }
    };

    // Worker-pool pattern: keep CONCURRENCY workers pulling from the
    // operations queue until all are processed. Preserves recordId →
    // result mapping via index.
    let cursor = 0;
    const slotResults = new Array(operations.length);
    const worker = async () => {
      while (true) {
        const i = cursor++;
        if (i >= operations.length) return;
        slotResults[i] = await processOperation(operations[i]);
      }
    };
    await Promise.all(
      Array.from({ length: Math.min(CONCURRENCY, operations.length) }, worker),
    );

    for (const r of slotResults) {
      if (!r) continue;
      if (r.kind === 'ok') {
        const { kind, ...rest } = r;
        results.push(rest);
      } else {
        errors.push({ recordId: r.recordId, error: r.error });
      }
    }

    // Update sync metadata
    await query(
      `INSERT INTO sync_metadata (user_id, table_name, last_synced_at)
       VALUES ($1, 'all', NOW())
       ON CONFLICT (user_id, table_name)
       DO UPDATE SET last_synced_at = NOW()`,
      [req.user.id]
    );

    res.json({
      success: true,
      message: 'Sync completed',
      data: {
        processed: operations.length,
        successful: results.length,
        failed: errors.length,
        results,
        errors,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get last sync time for user
 * GET /api/v1/sync/last?userId=:id
 */
const getLastSyncTime = async (req, res, next) => {
  try {
    const { userId } = req.query;

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'userId query parameter is required',
      });
    }

    // Users can only view their own sync time
    if (userId !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only view your own sync status',
      });
    }

    const result = await query(
      `SELECT table_name, last_synced_at
       FROM sync_metadata
       WHERE user_id = $1
       ORDER BY last_synced_at DESC`,
      [userId]
    );

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Helper function to handle CREATE operations
 */
async function handleCreate(table, data, userId) {
  // Validate user has permission to create in this table
  // Implement table-specific logic here
  // For now, return a simple response
  return { id: data.id || 'generated-id' };
}

/**
 * Helper function to handle UPDATE operations
 */
async function handleUpdate(table, recordId, data, userId) {
  // Validate user has permission to update this record
  // Implement table-specific logic here
  return { success: true };
}

/**
 * Helper function to handle DELETE operations
 */
async function handleDelete(table, recordId, userId) {
  // Validate user has permission to delete this record
  // Implement table-specific logic here
  return { success: true };
}

export default {
  syncData,
  getLastSyncTime,
};
