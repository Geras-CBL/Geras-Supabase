import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middlewares/authMiddleware';

const router = Router();

router.get('/profile', authMiddleware, (req: Request, res: Response) => {
  // Agora o user vem diretamente do Supabase Auth
  const user = (req as any).user;
  
  res.json({
    message: "Acedeste a uma rota protegida via Supabase Auth! 🔐",
    user_id: user.id, // O Supabase usa .id em vez de .sub
    email: user.email,
    last_sign_in: user.last_sign_in_at,
    role: user.role
  });
});

export default router;
