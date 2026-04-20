import { Router } from 'express';
import userRoutes from './user.routes';
import groceryRoutes from './grocery.routes';

const router = Router();

router.use('/profile', userRoutes);
router.use('/groceries', groceryRoutes);

export default router;
