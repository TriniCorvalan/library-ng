export interface Book {
  id: number;
  title: string;
  author: string;
  genre: string;
  year: number;
}

export type BookPayload = Omit<Book, 'id'>;
