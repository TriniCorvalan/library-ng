import { Component, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { Book } from '../../core/models/book.model';
import { AuthService } from '../../core/services/auth.service';
import { BookService } from '../../core/services/book.service';

@Component({
  selector: 'app-books',
  imports: [RouterLink],
  templateUrl: './books.html',
})
export class Books {
  protected readonly auth = inject(AuthService);
  private readonly booksApi = inject(BookService);

  protected readonly books = signal<Book[]>([]);
  protected readonly loading = signal(true);
  protected readonly error = signal<string | null>(null);
  protected readonly notice = signal<string | null>(readFlash());

  constructor() {
    this.load();
  }

  protected remove(book: Book): void {
    if (!confirm(`¿Eliminar "${book.title}"?`)) {
      return;
    }
    this.error.set(null);
    this.booksApi.delete(book.id).subscribe({
      next: () => {
        this.notice.set('Libro eliminado.');
        this.load();
      },
      error: () => this.error.set('No se pudo eliminar el libro.'),
    });
  }

  private load(): void {
    this.loading.set(true);
    this.booksApi.getAll().subscribe({
      next: (books) => {
        this.books.set(books);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.error.set('No se pudo cargar el catálogo. Verificá que el microservicio esté en el puerto 8080.');
      },
    });
  }
}

function readFlash(): string | null {
  const flash = history.state?.['flash'];
  return typeof flash === 'string' ? flash : null;
}
