import express, { json } from "express";
import { createServer } from "http";
import { Server } from "socket.io";
import cors from "cors";
import helmet from "helmet";

export const setupServer = () => {
  const app = express();
  const server = createServer(app);

  const raw = "https://sb-gameshow.vercel.app";
  const allowedOrigins = raw.split(",").map(s => s.trim()).filter(Boolean);

  console.log("[BOOT] CORS_ORIGIN env =", process.env.CORS_ORIGIN);
  console.log("[BOOT] allowedOrigins  =", allowedOrigins);
  
  const corsOptions = {
    origin: allowedOrigins,
    methods: ["GET", "POST"],
    credentials: true, // <- optional but useful
  };
  const io = new Server(server, {
    cors: corsOptions,
  });

  // Middleware
  app.use(helmet());
  app.use(cors(corsOptions));
  app.use(json());

  return { app, server, io };
};
