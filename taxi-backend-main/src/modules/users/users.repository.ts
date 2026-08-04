import { UserModel, UserDocument } from "./users.model";
import { UserEntity } from "./users.types";

export const findUserByEmail = async (email: string): Promise<UserDocument | null> => {
  return UserModel.findOne({ email: email.toLowerCase().trim() });
};

export const findUserById = async (id: string): Promise<UserDocument | null> => {
  return UserModel.findById(id);
};

export const createUser = async (payload: UserEntity): Promise<UserDocument> => {
  return UserModel.create(payload);
};
