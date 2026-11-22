import 'package:fpdart/fpdart.dart';
import 'package:campus_connect/core/failure.dart';

typedef FutureEither<T> = Future<Either<Failure, T>>;
typedef FutureVoid = FutureEither<void>;
