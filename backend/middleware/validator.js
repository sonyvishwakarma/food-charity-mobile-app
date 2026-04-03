const Joi = require('joi');

/**
 * Joi-based validation middleware
 * @param {Object} schema - Joi schema object
 */
const validate = (schema) => {
  return (req, res, next) => {
    // allowUnknown: true - ignores fields not in the schema
    // convert: true - attempts to convert strings to numbers etc. (important for multipart form-data)
    const { error, value } = schema.validate(req.body, { 
      abortEarly: false,
      allowUnknown: true,
      convert: true
    });
    
    if (error) {
      const errorMsgs = error.details.map(d => d.message);
      console.error('❌ Validation Error:', errorMsgs);
      console.error('❌ Body received:', JSON.stringify(req.body, null, 2));
      
      try {
        const fs = require('fs');
        const path = require('path');
        const logPath = path.join(__dirname, '..', 'validation_errors.log');
        const logEntry = `[${new Date().toISOString()}] ${req.method} ${req.url}\n` +
                         `Body: ${JSON.stringify(req.body)}\n` +
                         `Errors: ${JSON.stringify(errorMsgs)}\n\n`;
        fs.appendFileSync(logPath, logEntry);
      } catch (logErr) {
        console.error('Logging to file failed:', logErr.message);
      }

      const errorDetails = error.details.map(detail => ({
        message: detail.message,
        path: detail.path,
        type: detail.type
      }));

      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errorDetails.map(d => d.message),
        details: errorDetails
      });
    }

    // Replace req.body with the sanitized/converted value
    req.body = value;
    next();
  };
};

// Common Schemas
const schemas = {
  auth: {
    register: Joi.object({
      name: Joi.string().required().min(2),
      email: Joi.string().email({ tlds: { allow: false } }).allow('', null),
      phoneNumber: Joi.string().pattern(/^\+?[0-9\s-]{10,20}$/).allow('', null),
      phone: Joi.string().pattern(/^\+?[0-9\s-]{10,20}$/).allow('', null),
      role: Joi.string().valid('donor', 'volunteer', 'recipient', 'admin').required(),
      password: Joi.string().required().min(6),
      additionalInfo: Joi.alternatives().try(Joi.string(), Joi.object()).allow('', null)
    }).or('email', 'phoneNumber', 'phone'),
    
    login: Joi.object({
      email: Joi.string().email({ tlds: { allow: false } }),
      phone: Joi.string(),
      password: Joi.string().required(),
      loginMethod: Joi.string().valid('email', 'phone')
    }).or('email', 'phone'),
    
    forgotPassword: Joi.object({
      phoneNumber: Joi.string().pattern(/^\+?[0-9]{10,15}$/),
      email: Joi.string().email({ tlds: { allow: false } }),
      role: Joi.string()
    }).or('phoneNumber', 'email'),
    
    changePassword: Joi.object({
      currentPassword: Joi.string().required(),
      newPassword: Joi.string().required().min(6)
    })
  },
  
  donation: {
    create: Joi.object({
      donorId: Joi.any().allow('', null),
      foodType: Joi.any().allow('', null),
      category: Joi.any().allow('', null),
      quantity: Joi.any().allow('', null),
      servings: Joi.any().allow('', null),
      description: Joi.any().allow('', null),
      isVeg: Joi.any().allow('', null),
      pickupAddress: Joi.any().allow('', null),
      pickupDate: Joi.any().allow('', null),
      pickupTime: Joi.any().allow('', null),
      specialInstructions: Joi.any().allow('', null),
      contactNumber: Joi.any().allow('', null),
      hasAllergens: Joi.any().allow('', null),
      allergens: Joi.any().allow('', null),
      latitude: Joi.any().allow('', null),
      longitude: Joi.any().allow('', null),
      status: Joi.any(),
      createdAt: Joi.any()
    })
  },
  
  request: {
    create: Joi.object({
      recipientId: Joi.string().required(),
      foodType: Joi.string().required(),
      category: Joi.string().allow('', null),
      quantityRequired: Joi.alternatives().try(Joi.string(), Joi.number()).allow('', null),
      numberOfPeople: Joi.alternatives().try(Joi.string(), Joi.number()).allow('', null),
      preferredDate: Joi.string().allow('', null),
      preferredTime: Joi.string().allow('', null),
      specialRequirements: Joi.string().allow('', null),
      contactNumber: Joi.string().allow('', null),
      isVeg: Joi.alternatives().try(Joi.boolean(), Joi.string()),
      address: Joi.string().required(),
      latitude: Joi.number().allow(null, ''),
      longitude: Joi.number().allow(null, '')
    })
  }
};

module.exports = { validate, schemas };
