import { Injectable, computed, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import { AUTH_API_URL, AUTH_TOKEN_KEY, AUTH_USER_KEY } from '../constants/api.constants';
import { LoginRequest, LoginResponse, RegisterRequest, Usuario } from '../models/auth.model';

/** Singleton (`providedIn: 'root'`). Las llamadas HTTP exponen Observables (Observer). */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);

  private readonly token = signal<string | null>(readStorage(AUTH_TOKEN_KEY));
  private readonly usuario = signal<Usuario | null>(readUsuario());

  readonly isAuthenticated = computed(() => this.token() !== null);
  readonly currentUser = this.usuario.asReadonly();

  login(credentials: LoginRequest): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${AUTH_API_URL}/auth/login`, credentials).pipe(
      tap((response) => this.persist(response.token, response.usuario)),
    );
  }

  register(body: RegisterRequest): Observable<Usuario> {
    return this.http.post<Usuario>(`${AUTH_API_URL}/auth/register`, body);
  }

  logout(): void {
    localStorage.removeItem(AUTH_TOKEN_KEY);
    localStorage.removeItem(AUTH_USER_KEY);
    this.token.set(null);
    this.usuario.set(null);
  }

  getToken(): string | null {
    return this.token();
  }

  private persist(token: string, usuario: Usuario): void {
    localStorage.setItem(AUTH_TOKEN_KEY, token);
    localStorage.setItem(AUTH_USER_KEY, JSON.stringify(usuario));
    this.token.set(token);
    this.usuario.set(usuario);
  }
}

function readStorage(key: string): string | null {
  return localStorage.getItem(key);
}

function readUsuario(): Usuario | null {
  const raw = localStorage.getItem(AUTH_USER_KEY);
  if (!raw) {
    return null;
  }
  try {
    return JSON.parse(raw) as Usuario;
  } catch {
    return null;
  }
}
