import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

import { BOOKS_API_URL } from '../constants/api.constants';
import { Book, BookPayload } from '../models/book.model';

/** Singleton (`providedIn: 'root'`). El CRUD expone Observables (Observer). */
@Injectable({ providedIn: 'root' })
export class BookService {
  private readonly http = inject(HttpClient);

  getAll(): Observable<Book[]> {
    return this.http.get<Book[]>(BOOKS_API_URL);
  }

  getById(id: number): Observable<Book> {
    return this.http.get<Book>(`${BOOKS_API_URL}/${id}`);
  }

  create(book: BookPayload): Observable<Book> {
    return this.http.post<Book>(BOOKS_API_URL, book);
  }

  update(id: number, book: BookPayload): Observable<Book> {
    return this.http.put<Book>(`${BOOKS_API_URL}/${id}`, book);
  }

  delete(id: number): Observable<void> {
    return this.http.delete<void>(`${BOOKS_API_URL}/${id}`);
  }
}
