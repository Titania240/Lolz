const mongoose = require('mongoose');
const { MongooseError } = mongoose.Error;

// Configuration de la connexion
const connectDB = async () => {
  try {
    const conn = await mongoose.connect(
      `mongodb://${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`,
      {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        serverSelectionTimeoutMS: 5000,
      }
    );

    console.log(`MongoDB connected: ${conn.connection.host}`);

    // Configuration de la sécurité
    mongoose.connection.on('error', (err) => {
      console.error('MongoDB connection error:', err);
    });

    mongoose.connection.on('disconnected', () => {
      console.log('MongoDB disconnected');
    });

    // Validation des schémas
    mongoose.Error.messages.general.required = 'Ce champ est requis';
    mongoose.Error.messages.Number.min = 'Le nombre doit être supérieur à {MIN}';
    mongoose.Error.messages.Number.max = 'Le nombre doit être inférieur à {MAX}';
    mongoose.Error.messages.String.enum = '{VALUE} n\'est pas une valeur valide pour {PATH}';

    return conn;
  } catch (error) {
    console.error('MongoDB connection failed:', error);
    process.exit(1);
  }
};

// Middleware de validation des schémas
const validateSchema = (schema) => {
  return async (req, res, next) => {
    try {
      const data = req.body;
      const model = mongoose.model('Validation', schema);
      const instance = new model(data);
      await instance.validate();
      next();
    } catch (error) {
      if (error instanceof MongooseError.ValidationError) {
        return res.status(400).json({
          success: false,
          message: 'Validation error',
          errors: error.errors,
        });
      }
      next(error);
    }
  };
};

module.exports = {
  connectDB,
  validateSchema,
};
