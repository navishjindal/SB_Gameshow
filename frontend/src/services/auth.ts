import axios from "axios";
import { LoginCredentials, LoginResponse, RegisterCredentials, RegisterResponse } from "../types/auth.js";
import { API_BASE } from "../utils/constants";

const API = axios.create({
  baseURL: "https://sb-gameshow.onrender.com/api/auth",
  headers: {
    "Content-Type": "application/json",
  },
});

export const loginUser = async (
  credentials: LoginCredentials
): Promise<LoginResponse> => {
  const response = await API.post("/login", credentials); // ✅ CORRECT
  return response.data;
};

export const registerUser = async (
  credentials: RegisterCredentials
): Promise<RegisterResponse> => {
  const response = await API.post("/register", credentials);
  return response.data;
};
export default API;
