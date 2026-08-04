declare module "express-serve-static-core" {
  interface Request {
    authUser?: {
      userId: string;
      role: "ADMIN" | "CUSTOMER" | "DRIVER";
    };
  }
}

export {};
