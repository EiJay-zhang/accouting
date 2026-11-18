import { request } from '@/api/http'
import type { AppUser } from '@/models/types'

export interface ProfilePayload {
  [key: string]: unknown
  display_name?: string
  current_password?: string
  new_password?: string
}

export interface CreateUserPayload {
  [key: string]: unknown
  username: string
  password: string
  display_name?: string
}

export function updateProfile(payload: ProfilePayload): Promise<AppUser> {
  return request<AppUser>({
    url: '/api/auth/me',
    method: 'PUT',
    data: payload,
  })
}

export function fetchUsers(): Promise<AppUser[]> {
  return request<AppUser[]>({
    url: '/api/users',
  })
}

export function createUser(payload: CreateUserPayload): Promise<AppUser> {
  return request<AppUser>({
    url: '/api/users',
    method: 'POST',
    data: payload,
  })
}

export function deleteUser(id: number): Promise<void> {
  return request<void>({
    url: `/api/users/${id}`,
    method: 'DELETE',
  })
}
