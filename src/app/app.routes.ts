import { Routes } from '@angular/router';

import { authGuard } from './core/guards/auth.guard';
import { BookForm } from './pages/books/book-form/book-form';
import { Books } from './pages/books/books';
import { Login } from './pages/login/login';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'libros' },
  { path: 'login', component: Login },
  { path: 'libros', component: Books },
  { path: 'libros/nuevo', component: BookForm, canActivate: [authGuard] },
  { path: 'libros/:id', component: BookForm, canActivate: [authGuard] },
];
