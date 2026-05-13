// Template: backend/src/controllers/<resource>Controller.js
import <Resource> from '../models/<Resource>.js';
import Group from '../models/Group.js';
import GroupService from '../services/groupService.js';
import ActivityService from '../services/activityService.js';

const ACCESS_DENIED_MSG = 'User is not a member of this group';

/**
 * GET /api/v1/<resource>?groupId=...&page=1&limit=50
 */
const list = async (req, res, next) => {
  try {
    const { groupId, page = 1, limit = 50 } = req.query;
    if (!groupId) {
      return res.status(400).json({ success: false, error: 'groupId query parameter is required' });
    }

    await GroupService.validateGroupAccess(groupId, req.user.id);

    const offset = (page - 1) * limit;
    const items = await <Resource>.findByGroupId(groupId, parseInt(limit), offset);
    const total = await <Resource>.countByGroupId(groupId);

    res.json({
      success: true,
      data: items,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        hasMore: offset + items.length < total,
      },
    });
  } catch (error) {
    if (error.message === ACCESS_DENIED_MSG) {
      return res.status(403).json({ success: false, error: error.message });
    }
    next(error);
  }
};

/**
 * GET /api/v1/<resource>/:id
 */
const getOne = async (req, res, next) => {
  try {
    const { id } = req.params;
    const item = await <Resource>.findById(id);
    if (!item) return res.status(404).json({ success: false, error: '<Resource> not found' });

    await GroupService.validateGroupAccess(item.group_id, req.user.id);
    res.json({ success: true, data: item });
  } catch (error) {
    if (error.message === ACCESS_DENIED_MSG) {
      return res.status(403).json({ success: false, error: error.message });
    }
    next(error);
  }
};

/**
 * POST /api/v1/<resource>
 */
const create = async (req, res, next) => {
  try {
    const { groupId /* , ...fields */ } = req.body;
    await GroupService.validateGroupAccess(groupId, req.user.id);

    // For activity log — fetch group once
    const group = await Group.findById(groupId);

    const item = await <Resource>.create({ groupId, /* ...fields */ });

    // 1. Cache invalidation — match every read key the model produces
    <Resource>.invalidate(groupId);

    // 2. Activity log — pick the right ActivityService method
    // await ActivityService.log<Resource>Added(item.id, groupId, req.user.id, group.name, ...);

    res.status(201).json({ success: true, message: '<Resource> created successfully', data: item });
  } catch (error) {
    if (error.message === ACCESS_DENIED_MSG) {
      return res.status(403).json({ success: false, error: error.message });
    }
    next(error);
  }
};

/**
 * PUT /api/v1/<resource>/:id
 */
const update = async (req, res, next) => {
  try {
    const { id } = req.params;
    const existing = await <Resource>.findById(id);
    if (!existing) return res.status(404).json({ success: false, error: '<Resource> not found' });

    await GroupService.validateGroupAccess(existing.group_id, req.user.id);

    // OPTIONAL — only the original creator can edit:
    // if (existing.created_by !== req.user.id) {
    //   return res.status(403).json({ success: false, error: 'Only the creator can edit this' });
    // }

    const updated = await <Resource>.update(id, req.body);
    <Resource>.invalidate(existing.group_id);

    res.json({ success: true, message: '<Resource> updated successfully', data: updated });
  } catch (error) {
    next(error);
  }
};

/**
 * DELETE /api/v1/<resource>/:id  — soft delete
 */
const remove = async (req, res, next) => {
  try {
    const { id } = req.params;
    const existing = await <Resource>.findById(id);
    if (!existing) return res.status(404).json({ success: false, error: '<Resource> not found' });

    const isAdmin = await Group.isAdmin(existing.group_id, req.user.id);
    const isOwner = existing.created_by === req.user.id;
    if (!isAdmin && !isOwner) {
      return res.status(403).json({ success: false, error: 'Only group admins or the creator can delete this' });
    }

    const deleted = await <Resource>.delete(id);
    if (!deleted) return res.status(404).json({ success: false, error: '<Resource> not found' });

    <Resource>.invalidate(existing.group_id);
    res.json({ success: true, message: '<Resource> deleted successfully' });
  } catch (error) {
    next(error);
  }
};

export default { list, getOne, create, update, remove };
