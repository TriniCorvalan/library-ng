import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { BookPayload } from '../../../core/models/book.model';
import { BookService } from '../../../core/services/book.service';

@Component({
  selector: 'app-book-form',
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './book-form.html',
})
export class BookForm {
  private readonly booksApi = inject(BookService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  protected readonly editingId = readId(this.route.snapshot.paramMap.get('id'));
  protected readonly loading = signal(typeof this.editingId === 'number');
  protected readonly submitting = signal(false);
  protected readonly error = signal<string | null>(this.editingId === undefined ? 'Identificador inválido.' : null);

  protected readonly form = inject(FormBuilder).nonNullable.group({
    title: ['', [Validators.required, Validators.maxLength(200)]],
    author: ['', [Validators.required, Validators.maxLength(200)]],
    genre: ['', [Validators.required, Validators.maxLength(100)]],
    year: [new Date().getFullYear(), [Validators.required, Validators.min(1), Validators.max(2100)]],
  });

  constructor() {
    if (typeof this.editingId === 'number') {
      this.booksApi.getById(this.editingId).subscribe({
        next: (book) => {
          this.form.patchValue({
            title: book.title,
            author: book.author,
            genre: book.genre,
            year: book.year,
          });
          this.loading.set(false);
        },
        error: () => {
          this.loading.set(false);
          this.error.set('No se encontró el libro.');
        },
      });
    }
  }

  protected submit(): void {
    if (this.form.invalid || this.editingId === undefined) {
      this.form.markAllAsTouched();
      return;
    }

    const raw = this.form.getRawValue();
    const payload: BookPayload = {
      title: raw.title.trim(),
      author: raw.author.trim(),
      genre: raw.genre.trim(),
      year: Number(raw.year),
    };

    this.error.set(null);
    this.submitting.set(true);
    const request =
      this.editingId === null
        ? this.booksApi.create(payload)
        : this.booksApi.update(this.editingId, payload);

    request.subscribe({
      next: () => {
        void this.router.navigate(['/libros'], {
          state: { flash: this.editingId === null ? 'Libro creado.' : 'Libro actualizado.' },
        });
      },
      error: () => {
        this.submitting.set(false);
        this.error.set('No se pudo guardar el libro.');
      },
    });
  }
}

function readId(value: string | null): number | null | undefined {
  if (value === null) {
    return null;
  }
  const id = Number(value);
  return Number.isInteger(id) && id > 0 ? id : undefined;
}
