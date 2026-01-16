/// Base interface for all repositories
abstract class Repository {
  Future<void> initialize();
  Future<void> dispose();
}

/// Generic CRUD repository interface
abstract class CrudRepository<T, ID> extends Repository {
  Future<ID> insert(T entity);
  Future<T?> findById(ID id);
  Future<List<T>> findAll();
  Future<void> update(T entity);
  Future<void> delete(ID id);
}
