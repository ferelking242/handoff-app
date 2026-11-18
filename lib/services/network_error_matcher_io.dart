import 'dart:io';

bool isSocketOrHttpError(Object? error) =>
    error is SocketException || error is HttpException;
