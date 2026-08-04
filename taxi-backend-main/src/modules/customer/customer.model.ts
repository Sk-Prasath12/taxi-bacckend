import { UserModel, UserDocument } from "../users/users.model";

// Customer auth uses the shared `users` collection.
export type CustomerDocument = UserDocument;
export const CustomerModel = UserModel;
