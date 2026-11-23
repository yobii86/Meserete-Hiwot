import 'json.dart';

/// Reading & audio narration progress for a book.
class BookProgress {
  const BookProgress({
    this.page = 1,
    this.pageCount,
    this.audioPositionMs = 0,
    this.updatedAt,
  });

  final int page;
  final int? pageCount;
  final int audioPositionMs;
  final DateTime? updatedAt;

  factory BookProgress.fromJson(Json j) => BookProgress(
        page: asIntOr(j['page'], 1),
        pageCount: asInt(j['page_count']),
        audioPositionMs: asIntOr(j['audio_position_ms']),
        updatedAt: asDate(j['updated_at']),
      );

  Json toJson() => {
        'page': page,
        'page_count': ?pageCount,
        'audio_position_ms': audioPositionMs,
        'updated_at': updatedAt?.toIso8601String(),
      };
}

/// A library book: printed (borrowed with a signature) or digital (a PDF to download).
class Book {
  const Book({
    required this.id,
    required this.title,
    this.author,
    this.subtitle,
    this.publisher,
    this.publicationYear,
    this.language,
    this.categoryType,
    required this.code,
    this.kind = 'physical',
    this.category,
    this.categoryId,
    this.categoryName,
    this.description,
    this.coverUrl,
    this.available,
    this.quantity,
    this.copiesAvailable,
    this.copiesTotal,
    this.fileUrl,
    this.fileSize,
    this.narrationUrl,
    this.narrationMime,
    this.narrationDuration,
    this.downloads = 0,
    this.isFavorite = false,
    this.progress,
    this.myRequest,
    this.status = 'active',
    this.condition,
    this.location,
    this.notes,
    this.domain = 'mezmur',
  });

  final int id;
  final String title;
  final String? author;
  final String? subtitle;
  final String? publisher;
  final int? publicationYear;
  final String? language;
  final String? categoryType;
  final String code;
  final String kind; // physical | digital
  final String? category;
  final int? categoryId;
  final String? categoryName;
  final String? description;
  final String? coverUrl;
  final int? available;
  final int? quantity;
  final int? copiesAvailable;
  final int? copiesTotal;
  final String? fileUrl;
  final int? fileSize;
  final String? narrationUrl;
  final String? narrationMime;
  final int? narrationDuration;
  final int downloads;
  final bool isFavorite;
  final BookProgress? progress;

  /// requested | approved — the signed-in member's open request for this book.
  final String? myRequest;
  final String status;
  final String? condition;
  final String? location;
  final String? notes;
  final String domain;

  bool get isDigital => kind == 'digital';
  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get hasNarration => narrationUrl != null && narrationUrl!.isNotEmpty;
  int get effectiveAvailable => copiesAvailable ?? available ?? 0;
  int get effectiveTotal => copiesTotal ?? quantity ?? 0;
  String get languageLabel => switch (language) {
        'am' => 'አማርኛ',
        'gez' => 'ግዕዝ',
        'en' => 'English',
        'om' => 'Afaan Oromoo',
        'ti' => 'ትግርኛ',
        _ => language ?? '—',
      };

  Book copyWith({
    bool? isFavorite,
    BookProgress? progress,
    String? subtitle,
    String? publisher,
    int? publicationYear,
    String? language,
    String? categoryType,
  }) =>
      Book(
        id: id,
        title: title,
        author: author,
        subtitle: subtitle ?? this.subtitle,
        publisher: publisher ?? this.publisher,
        publicationYear: publicationYear ?? this.publicationYear,
        language: language ?? this.language,
        categoryType: categoryType ?? this.categoryType,
        code: code,
        kind: kind,
        category: category,
        categoryId: categoryId,
        categoryName: categoryName,
        description: description,
        coverUrl: coverUrl,
        available: available,
        quantity: quantity,
        copiesAvailable: copiesAvailable,
        copiesTotal: copiesTotal,
        fileUrl: fileUrl,
        fileSize: fileSize,
        narrationUrl: narrationUrl,
        narrationMime: narrationMime,
        narrationDuration: narrationDuration,
        downloads: downloads,
        isFavorite: isFavorite ?? this.isFavorite,
        progress: progress ?? this.progress,
        myRequest: myRequest,
      );

  factory Book.fromJson(Json j) {
    final progJson = asJson(j['progress']);
    return Book(
      id: asIntOr(j['id']),
      title: asStr(j['title']) ?? asStr(j['name']) ?? '',
      author: asStr(j['author']),
      subtitle: asStr(j['subtitle']),
      publisher: asStr(j['publisher']),
      publicationYear: asInt(j['publication_year']),
      language: asStr(j['language']),
      categoryType: asStr(j['category_type']),
      code: asStr(j['code']) ?? '',
      kind: asStr(j['kind']) ?? 'physical',
      category: asStr(j['category']),
      categoryId: asInt(j['category_id'] ?? j['library_category_id']),
      categoryName: asStr(j['category_name']),
      description: asStr(j['description']),
      coverUrl: asStr(j['cover_url']),
      available: asInt(j['available']),
      quantity: asInt(j['quantity']),
      copiesAvailable: asInt(j['copies_available']),
      copiesTotal: asInt(j['copies_total']),
      fileUrl: asStr(j['file_url']),
      fileSize: asInt(j['file_size']),
      narrationUrl: asStr(j['narration_url']),
      narrationMime: asStr(j['narration_mime']),
      narrationDuration: asInt(j['narration_duration']),
      downloads: asIntOr(j['downloads']),
      isFavorite: j['is_favorite'] == true || j['is_favorite'] == 1,
      progress: progJson.isNotEmpty ? BookProgress.fromJson(progJson) : null,
      myRequest: asStr(j['my_request']),
      status: asStr(j['status']) ?? 'active',
      condition: asStr(j['condition']),
      location: asStr(j['location']),
      notes: asStr(j['notes']),
      domain: asStr(j['domain']) ?? 'mezmur',
    );
  }

  Json toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'subtitle': subtitle,
        'publisher': publisher,
        'publication_year': publicationYear,
        'language': language,
        'category_type': categoryType,
        'code': code,
        'kind': kind,
        'category': category,
        'category_id': categoryId,
        'category_name': categoryName,
        'description': description,
        'cover_url': coverUrl,
        'available': available,
        'quantity': quantity,
        'copies_available': copiesAvailable,
        'copies_total': copiesTotal,
        'file_url': fileUrl,
        'file_size': fileSize,
        'narration_url': narrationUrl,
        'narration_mime': narrationMime,
        'narration_duration': narrationDuration,
        'downloads': downloads,
        'is_favorite': isFavorite,
        'progress': progress?.toJson(),
        'my_request': myRequest,
      };
}

/// Category hierarchy for books (F16).
class LibraryCategory {
  const LibraryCategory({
    required this.id,
    this.parentId,
    this.domain = 'timhirt',
    required this.name,
    this.nameEn,
    this.code,
    this.categoryType = 'physical',
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
    this.booksCount = 0,
    this.children = const [],
  });

  final int id;
  final int? parentId;
  final String domain;
  final String name;
  final String? nameEn;
  final String? code;
  final String categoryType;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final int booksCount;
  final List<LibraryCategory> children;

  factory LibraryCategory.fromJson(Json j) => LibraryCategory(
        id: asIntOr(j['id']),
        parentId: asInt(j['parent_id']),
        domain: asStr(j['domain']) ?? 'timhirt',
        name: asStr(j['name']) ?? '',
        nameEn: asStr(j['name_en']),
        code: asStr(j['code']),
        categoryType: asStr(j['category_type']) ?? 'physical',
        description: asStr(j['description']),
        isActive: j['is_active'] == null || j['is_active'] == true || j['is_active'] == 1,
        sortOrder: asIntOr(j['sort_order']),
        booksCount: asIntOr(j['books_count']),
        children: asJsonList(j['children']).map(LibraryCategory.fromJson).toList(),
      );

  Json toJson() => {
        'id': id,
        'parent_id': parentId,
        'domain': domain,
        'name': name,
        'name_en': nameEn,
        'code': code,
        'category_type': categoryType,
        'description': description,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}

/// Physical library copy item (F17).
class LibraryCopy {
  const LibraryCopy({
    required this.id,
    required this.itemId,
    this.bookTitle,
    this.bookAuthor,
    this.bookCode,
    this.categoryName,
    required this.copyNo,
    required this.copyCode,
    this.condition = 'good',
    this.location,
    this.status = 'available',
    this.currentLoan,
    this.createdAt,
  });

  final int id;
  final int itemId;
  final String? bookTitle;
  final String? bookAuthor;
  final String? bookCode;
  final String? categoryName;
  final int copyNo;
  final String copyCode;
  final String condition;
  final String? location;
  final String status;
  final CurrentLoanSummary? currentLoan;
  final DateTime? createdAt;

  bool get isAvailable => status == 'available';
  bool get isOnLoan => status == 'on_loan';

  factory LibraryCopy.fromJson(Json j) {
    final loanJson = asJson(j['current_loan']);
    return LibraryCopy(
      id: asIntOr(j['id']),
      itemId: asIntOr(j['item_id']),
      bookTitle: asStr(j['book_title']),
      bookAuthor: asStr(j['book_author']),
      bookCode: asStr(j['book_code']),
      categoryName: asStr(j['category_name']),
      copyNo: asIntOr(j['copy_no'], 1),
      copyCode: asStr(j['copy_code']) ?? '',
      condition: asStr(j['condition']) ?? 'good',
      location: asStr(j['location']),
      status: asStr(j['status']) ?? 'available',
      currentLoan: loanJson.isNotEmpty ? CurrentLoanSummary.fromJson(loanJson) : null,
      createdAt: asDate(j['created_at']),
    );
  }
}

class CurrentLoanSummary {
  const CurrentLoanSummary({
    required this.id,
    required this.userId,
    this.borrowerName,
    this.memberId,
    this.checkedOutAt,
    this.dueOn,
  });

  final int id;
  final int userId;
  final String? borrowerName;
  final String? memberId;
  final DateTime? checkedOutAt;
  final DateTime? dueOn;

  factory CurrentLoanSummary.fromJson(Json j) => CurrentLoanSummary(
        id: asIntOr(j['id']),
        userId: asIntOr(j['user_id']),
        borrowerName: asStr(j['borrower_name']),
        memberId: asStr(j['member_id']),
        checkedOutAt: asDate(j['checked_out_at']),
        dueOn: asDate(j['due_on']),
      );
}

/// Physical library loan record (F17).
class LibraryLoan {
  const LibraryLoan({
    required this.id,
    required this.copyId,
    required this.copyCode,
    required this.bookId,
    this.bookTitle,
    this.bookAuthor,
    required this.userId,
    this.borrowerName,
    this.borrowerPhone,
    this.memberId,
    this.checkedOutAt,
    this.dueOn,
    this.returnedAt,
    this.conditionOut = 'good',
    this.conditionIn,
    this.issuedBy = 0,
    this.issuerName,
    this.receivedBy,
    this.receiverName,
    this.signatureUrl,
    this.notes,
    this.status = 'active',
    this.createdAt,
  });

  final int id;
  final int copyId;
  final String copyCode;
  final int bookId;
  final String? bookTitle;
  final String? bookAuthor;
  final int userId;
  final String? borrowerName;
  final String? borrowerPhone;
  final String? memberId;
  final DateTime? checkedOutAt;
  final DateTime? dueOn;
  final DateTime? returnedAt;
  final String conditionOut;
  final String? conditionIn;
  final int issuedBy;
  final String? issuerName;
  final int? receivedBy;
  final String? receiverName;
  final String? signatureUrl;
  final String? notes;
  final String status;
  final DateTime? createdAt;

  bool get isActive => status == 'active';
  bool get isReturned => status == 'returned';
  bool get isOverdue => isActive && dueOn != null && DateTime.now().isAfter(dueOn!);

  factory LibraryLoan.fromJson(Json j) => LibraryLoan(
        id: asIntOr(j['id']),
        copyId: asIntOr(j['copy_id']),
        copyCode: asStr(j['copy_code']) ?? '',
        bookId: asIntOr(j['book_id']),
        bookTitle: asStr(j['book_title']),
        bookAuthor: asStr(j['book_author']),
        userId: asIntOr(j['user_id']),
        borrowerName: asStr(j['borrower_name']),
        borrowerPhone: asStr(j['borrower_phone']),
        memberId: asStr(j['member_id']),
        checkedOutAt: asDate(j['checked_out_at']),
        dueOn: asDate(j['due_on']),
        returnedAt: asDate(j['returned_at']),
        conditionOut: asStr(j['condition_out']) ?? 'good',
        conditionIn: asStr(j['condition_in']),
        issuedBy: asIntOr(j['issued_by']),
        issuerName: asStr(j['issuer_name']),
        receivedBy: asInt(j['received_by']),
        receiverName: asStr(j['receiver_name']),
        signatureUrl: asStr(j['signature_url']),
        notes: asStr(j['notes']),
        status: asStr(j['status']) ?? 'active',
        createdAt: asDate(j['created_at']),
      );
}

class BookRequest {
  const BookRequest({
    required this.id,
    required this.status,
    this.quantity = 1,
    this.note,
    this.reviewNote,
    this.borrowingId,
    required this.bookId,
    required this.bookTitle,
    this.bookCode,
    this.bookCoverUrl,
    this.bookAvailable = 0,
    this.userId,
    this.userName,
    this.userMemberId,
    this.userPhone,
    this.createdAt,
    this.neededOn,
  });

  final int id;
  final String status; // requested | approved | rejected | issued | cancelled
  final int quantity;
  final String? note;
  final String? reviewNote;
  final int? borrowingId;
  final int bookId;
  final String bookTitle;
  final String? bookCode;
  final String? bookCoverUrl;
  final int bookAvailable;
  final int? userId;
  final String? userName;
  final String? userMemberId;
  final String? userPhone;
  final DateTime? createdAt;
  final DateTime? neededOn;

  bool get isOpen => status == 'requested' || status == 'approved';

  factory BookRequest.fromJson(Json j) {
    final b = asJson(j['book']);
    final u = asJson(j['user']);
    return BookRequest(
      id: asIntOr(j['id']),
      status: asStr(j['status']) ?? 'requested',
      quantity: asIntOr(j['quantity'], 1),
      note: asStr(j['note']),
      reviewNote: asStr(j['review_note']),
      borrowingId: asInt(j['borrowing_id']),
      bookId: asIntOr(b['id']),
      bookTitle: asStr(b['title']) ?? asStr(b['name']) ?? '',
      bookCode: asStr(b['code']),
      bookCoverUrl: asStr(b['cover_url']),
      bookAvailable: asIntOr(b['available']),
      userId: asInt(u['id']),
      userName: asStr(u['full_name']),
      userMemberId: asStr(u['member_id']),
      userPhone: asStr(u['phone']),
      createdAt: asDate(j['created_at']),
      neededOn: asDate(j['needed_on']),
    );
  }
}
