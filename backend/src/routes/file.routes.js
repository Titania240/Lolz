const express = require('express');
const router = express.Router();
const { uploadFile, uploadFiles, getFile, deleteFile } = require('../services/fileService');
const { authMiddleware } = require('../middleware/authMiddleware');

// Upload single file
router.post('/upload', authMiddleware, uploadFile, async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded',
      });
    }

    res.json({
      success: true,
      message: 'File uploaded successfully',
      file: {
        url: req.file.location,
        filename: req.file.key,
      },
    });
  } catch (error) {
    next(error);
  }
});

// Upload multiple files
router.post('/upload/multiple', authMiddleware, uploadFiles, async (req, res, next) => {
  try {
    if (!req.files) {
      return res.status(400).json({
        success: false,
        message: 'No files uploaded',
      });
    }

    const files = req.files.map(file => ({
      url: file.location,
      filename: file.key,
    }));

    res.json({
      success: true,
      message: 'Files uploaded successfully',
      files,
    });
  } catch (error) {
    next(error);
  }
});

// Get file
router.get('/:filename', authMiddleware, async (req, res, next) => {
  try {
    const file = await getFile(req.params.filename);
    res.json({
      success: true,
      file: {
        url: file.Location,
        filename: req.params.filename,
      },
    });
  } catch (error) {
    next(error);
  }
});

// Delete file
router.delete('/:filename', authMiddleware, async (req, res, next) => {
  try {
    await deleteFile(req.params.filename);
    res.json({
      success: true,
      message: 'File deleted successfully',
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
