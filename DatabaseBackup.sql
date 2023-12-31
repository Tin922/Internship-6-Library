PGDMP     *    4                {            backupLibrary    15.3    15.3 M    Z           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            [           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            \           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            ]           1262    34006    backupLibrary    DATABASE     �   CREATE DATABASE "backupLibrary" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'English_Denmark.1252';
    DROP DATABASE "backupLibrary";
                postgres    false            �            1255    34110 "   calculatereturnfeeandsave(integer)    FUNCTION     �  CREATE FUNCTION public.calculatereturnfeeandsave(in_borrowing_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    return_fee DECIMAL(5, 2) := 0.50; 
    is_lektira BOOLEAN;
    is_summer BOOLEAN;
    days_late INT;
BEGIN
    
    SELECT
        CASE WHEN b.BookType = 'TEXTBOOK' THEN TRUE ELSE FALSE END
    INTO is_lektira
    FROM
        Borrowings bor
        JOIN Copies c ON bor.CopyID = c.CopyID
        JOIN Books b ON c.BookID = b.BookID
    WHERE
        bor.BorrowingID = in_borrowing_id;

    
    SELECT
        CASE WHEN EXTRACT(MONTH FROM bor.ReturnDate) BETWEEN 6 AND 9 THEN TRUE ELSE FALSE END
    INTO is_summer
    FROM
        Borrowings bor
    WHERE
        bor.BorrowingID = in_borrowing_id;    

SELECT 	(SELECT ReturnDate FROM Borrowings WHERE BorrowingID = in_borrowing_id) - (SELECT DueDate FROM Borrowings WHERE BorrowingID = in_borrowing_id) INTO days_late;



   
    IF is_lektira THEN
        
        IF is_summer THEN
            
            return_fee := 0.50 * days_late;  
        ELSE
           
            return_fee := 0.50 * days_late;  
        END IF;
    ELSE
        
        IF is_summer THEN
            
            IF EXTRACT(ISODOW FROM (SELECT ReturnDate FROM Borrowings WHERE BorrowingID = in_borrowing_id)) IN (6, 7) THEN
            
                return_fee := 0.20 * days_late;  
            ELSE
                
                return_fee := 0.30 * days_late;  
            END IF;
        ELSE
          
            IF EXTRACT(ISODOW FROM (SELECT ReturnDate FROM Borrowings WHERE BorrowingID = in_borrowing_id)) IN (6, 7) THEN
               
                return_fee := 0.20 * days_late;  
            ELSE
                
                return_fee := 0.40 * days_late;  
            END IF;
        END IF;
    END IF;

   
    UPDATE Borrowings
    SET LateFee = return_fee
    WHERE BorrowingID = in_borrowing_id;

    RETURN return_fee;
END;
$$;
 I   DROP FUNCTION public.calculatereturnfeeandsave(in_borrowing_id integer);
       public          postgres    false            �            1255    34114 "   extendreturndate(integer, integer) 	   PROCEDURE     o  CREATE PROCEDURE public.extendreturndate(IN borrowing_id integer, IN extension_days_to_add integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_date DATE;
    original_due_date DATE;
    extended_due_date DATE;
    extension_days INT;
    max_extension_days INT := 40;
BEGIN
   
    SELECT CURRENT_DATE INTO current_date;

   
    SELECT DueDate, ExtensionDays
    INTO original_due_date, extension_days
    FROM Borrowings
    WHERE BorrowingID = borrowing_id;

 
    IF original_due_date IS NULL THEN
        RAISE EXCEPTION 'Borrowing with ID % does not exist.', borrowing_id;
    END IF;

 
    IF extension_days + extension_days_to_add > max_extension_days THEN
        RAISE EXCEPTION 'Extension limit (% days) reached for BorrowingID %.', max_extension_days, borrowing_id;
    END IF;

    
   extended_due_date := LEAST(original_due_date + interval '60 days', original_due_date + interval '1 day' * extension_days_to_add);


   UPDATE Borrowings
    SET ReturnDate = NULL,
        DueDate = extended_due_date,
        ExtensionDays = extension_days + extension_days_to_add
    WHERE BorrowingID = borrowing_id;
END;
$$;
 c   DROP PROCEDURE public.extendreturndate(IN borrowing_id integer, IN extension_days_to_add integer);
       public          postgres    false            �            1255    34113    lendbook(integer, integer) 	   PROCEDURE     @  CREATE PROCEDURE public.lendbook(IN copy_id integer, IN user_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    due_date DATE;
    is_copy_available BOOLEAN;
    num_loaned_books INT;
    new_borrowing_id INT;
BEGIN
  
    IF NOT EXISTS (SELECT 1 FROM Users WHERE UserID = user_id) THEN
        RAISE EXCEPTION 'The specified user does not exist.';
    END IF;

    
    SELECT COUNT(*) INTO num_loaned_books
    FROM Borrowings
    WHERE UserID = user_id AND ReturnDate IS NULL;

    
    IF num_loaned_books >= 3 THEN
        RAISE EXCEPTION 'User has already borrowed 3 books and cannot borrow more.';
    END IF;

    
    IF NOT EXISTS (SELECT 1 FROM Copies WHERE CopyID = copy_id) THEN
        RAISE EXCEPTION 'The specified copy does not exist.';
    END IF;


    SELECT COUNT(*) = 0 INTO is_copy_available
    FROM Borrowings
    WHERE CopyID = copy_id AND ReturnDate IS NULL;

    IF NOT is_copy_available THEN
        RAISE EXCEPTION 'The book copy is already borrowed and cannot be lent again.';
    END IF;


    SELECT COALESCE(MAX(BorrowingID), 0) + 1 INTO new_borrowing_id
    FROM Borrowings;


    SELECT CURRENT_DATE + INTERVAL '20 days' INTO due_date;


    INSERT INTO Borrowings (BorrowingID, BorrowDate, DueDate, CopyID, UserID)
    VALUES (new_borrowing_id, CURRENT_DATE, due_date, copy_id, user_id);

    
END;
$$;
 H   DROP PROCEDURE public.lendbook(IN copy_id integer, IN user_id integer);
       public          postgres    false            �            1255    34108    setduedatefunction()    FUNCTION     �   CREATE FUNCTION public.setduedatefunction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.DueDate := NEW.BorrowDate + INTERVAL '20 days';
    RETURN NEW;
END;
$$;
 +   DROP FUNCTION public.setduedatefunction();
       public          postgres    false            �            1255    34111    update_late_fee_after_insert()    FUNCTION     �   CREATE FUNCTION public.update_late_fee_after_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.LateFee := CalculateReturnFeeAndSave(NEW.BorrowingID);
    RETURN NEW;
END;
$$;
 5   DROP FUNCTION public.update_late_fee_after_insert();
       public          postgres    false            �            1259    34046    authors    TABLE     �  CREATE TABLE public.authors (
    authorid integer NOT NULL,
    name character varying(50),
    dateofbirth date NOT NULL,
    dateofdeath date,
    authorgender character varying(50),
    fieldofstudy character varying(50) NOT NULL,
    countryid integer,
    CONSTRAINT ck_gender CHECK (((authorgender)::text = ANY ((ARRAY['MALE'::character varying, 'FEMALE'::character varying, 'UNKNOWN'::character varying, 'OTHER'::character varying])::text[])))
);
    DROP TABLE public.authors;
       public         heap    postgres    false            �            1259    34045    authors_authorid_seq    SEQUENCE     �   CREATE SEQUENCE public.authors_authorid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.authors_authorid_seq;
       public          postgres    false    223            ^           0    0    authors_authorid_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.authors_authorid_seq OWNED BY public.authors.authorid;
          public          postgres    false    222            �            1259    34057    authorships    TABLE        CREATE TABLE public.authorships (
    authorid integer NOT NULL,
    bookid integer NOT NULL,
    authorship character varying(20) NOT NULL,
    CONSTRAINT ck_authortype CHECK (((authorship)::text = ANY ((ARRAY['MAIN'::character varying, 'CONTRIBUTING'::character varying])::text[])))
);
    DROP TABLE public.authorships;
       public         heap    postgres    false            �            1259    34022    books    TABLE     �  CREATE TABLE public.books (
    bookid integer NOT NULL,
    title character varying(200) NOT NULL,
    dateofpublishment date NOT NULL,
    booktype character varying(50) NOT NULL,
    CONSTRAINT ck_booktype CHECK (((booktype)::text = ANY ((ARRAY['TEXTBOOK'::character varying, 'ARTISTIC'::character varying, 'SCIENTIFIC'::character varying, 'BIOGRAPHY'::character varying, 'PROFESSIONAL'::character varying])::text[])))
);
    DROP TABLE public.books;
       public         heap    postgres    false            �            1259    34021    books_bookid_seq    SEQUENCE     �   CREATE SEQUENCE public.books_bookid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.books_bookid_seq;
       public          postgres    false    219            _           0    0    books_bookid_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.books_bookid_seq OWNED BY public.books.bookid;
          public          postgres    false    218            �            1259    34087 
   borrowings    TABLE     :  CREATE TABLE public.borrowings (
    borrowingid integer NOT NULL,
    borrowdate date NOT NULL,
    duedate date NOT NULL,
    returndate date,
    extensiondays integer DEFAULT 0,
    latefee numeric(5,2),
    copyid integer,
    userid integer,
    CONSTRAINT ck_returndate CHECK ((returndate > borrowdate))
);
    DROP TABLE public.borrowings;
       public         heap    postgres    false            �            1259    34086    borrowings_borrowingid_seq    SEQUENCE     �   CREATE SEQUENCE public.borrowings_borrowingid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.borrowings_borrowingid_seq;
       public          postgres    false    230            `           0    0    borrowings_borrowingid_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.borrowings_borrowingid_seq OWNED BY public.borrowings.borrowingid;
          public          postgres    false    229            �            1259    34029    copies    TABLE     �   CREATE TABLE public.copies (
    copyid integer NOT NULL,
    code character varying(50) NOT NULL,
    bookid integer,
    libraryid integer
);
    DROP TABLE public.copies;
       public         heap    postgres    false            �            1259    34028    copies_copyid_seq    SEQUENCE     �   CREATE SEQUENCE public.copies_copyid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.copies_copyid_seq;
       public          postgres    false    221            a           0    0    copies_copyid_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.copies_copyid_seq OWNED BY public.copies.copyid;
          public          postgres    false    220            �            1259    34008 	   countries    TABLE     �   CREATE TABLE public.countries (
    countryid integer NOT NULL,
    name character varying(50),
    population integer NOT NULL,
    averagesalary double precision NOT NULL
);
    DROP TABLE public.countries;
       public         heap    postgres    false            �            1259    34007    countries_countryid_seq    SEQUENCE     �   CREATE SEQUENCE public.countries_countryid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.countries_countryid_seq;
       public          postgres    false    215            b           0    0    countries_countryid_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.countries_countryid_seq OWNED BY public.countries.countryid;
          public          postgres    false    214            �            1259    34073 	   librarian    TABLE     d   CREATE TABLE public.librarian (
    librarianid integer NOT NULL,
    name character varying(50)
);
    DROP TABLE public.librarian;
       public         heap    postgres    false            �            1259    34072    librarian_librarianid_seq    SEQUENCE     �   CREATE SEQUENCE public.librarian_librarianid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.librarian_librarianid_seq;
       public          postgres    false    226            c           0    0    librarian_librarianid_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.librarian_librarianid_seq OWNED BY public.librarian.librarianid;
          public          postgres    false    225            �            1259    34015 	   libraries    TABLE     �   CREATE TABLE public.libraries (
    libraryid integer NOT NULL,
    name character varying(80) NOT NULL,
    openingtime character varying(50),
    closingtime character varying(50)
);
    DROP TABLE public.libraries;
       public         heap    postgres    false            �            1259    34014    libraries_libraryid_seq    SEQUENCE     �   CREATE SEQUENCE public.libraries_libraryid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.libraries_libraryid_seq;
       public          postgres    false    217            d           0    0    libraries_libraryid_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.libraries_libraryid_seq OWNED BY public.libraries.libraryid;
          public          postgres    false    216            �            1259    34080    users    TABLE     d   CREATE TABLE public.users (
    userid integer NOT NULL,
    name character varying(50) NOT NULL
);
    DROP TABLE public.users;
       public         heap    postgres    false            �            1259    34079    users_userid_seq    SEQUENCE     �   CREATE SEQUENCE public.users_userid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.users_userid_seq;
       public          postgres    false    228            e           0    0    users_userid_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.users_userid_seq OWNED BY public.users.userid;
          public          postgres    false    227            �           2604    34049    authors authorid    DEFAULT     t   ALTER TABLE ONLY public.authors ALTER COLUMN authorid SET DEFAULT nextval('public.authors_authorid_seq'::regclass);
 ?   ALTER TABLE public.authors ALTER COLUMN authorid DROP DEFAULT;
       public          postgres    false    223    222    223            �           2604    34025    books bookid    DEFAULT     l   ALTER TABLE ONLY public.books ALTER COLUMN bookid SET DEFAULT nextval('public.books_bookid_seq'::regclass);
 ;   ALTER TABLE public.books ALTER COLUMN bookid DROP DEFAULT;
       public          postgres    false    219    218    219            �           2604    34090    borrowings borrowingid    DEFAULT     �   ALTER TABLE ONLY public.borrowings ALTER COLUMN borrowingid SET DEFAULT nextval('public.borrowings_borrowingid_seq'::regclass);
 E   ALTER TABLE public.borrowings ALTER COLUMN borrowingid DROP DEFAULT;
       public          postgres    false    230    229    230            �           2604    34032    copies copyid    DEFAULT     n   ALTER TABLE ONLY public.copies ALTER COLUMN copyid SET DEFAULT nextval('public.copies_copyid_seq'::regclass);
 <   ALTER TABLE public.copies ALTER COLUMN copyid DROP DEFAULT;
       public          postgres    false    221    220    221            �           2604    34011    countries countryid    DEFAULT     z   ALTER TABLE ONLY public.countries ALTER COLUMN countryid SET DEFAULT nextval('public.countries_countryid_seq'::regclass);
 B   ALTER TABLE public.countries ALTER COLUMN countryid DROP DEFAULT;
       public          postgres    false    214    215    215            �           2604    34076    librarian librarianid    DEFAULT     ~   ALTER TABLE ONLY public.librarian ALTER COLUMN librarianid SET DEFAULT nextval('public.librarian_librarianid_seq'::regclass);
 D   ALTER TABLE public.librarian ALTER COLUMN librarianid DROP DEFAULT;
       public          postgres    false    225    226    226            �           2604    34018    libraries libraryid    DEFAULT     z   ALTER TABLE ONLY public.libraries ALTER COLUMN libraryid SET DEFAULT nextval('public.libraries_libraryid_seq'::regclass);
 B   ALTER TABLE public.libraries ALTER COLUMN libraryid DROP DEFAULT;
       public          postgres    false    216    217    217            �           2604    34083    users userid    DEFAULT     l   ALTER TABLE ONLY public.users ALTER COLUMN userid SET DEFAULT nextval('public.users_userid_seq'::regclass);
 ;   ALTER TABLE public.users ALTER COLUMN userid DROP DEFAULT;
       public          postgres    false    227    228    228            P          0    34046    authors 
   TABLE DATA           r   COPY public.authors (authorid, name, dateofbirth, dateofdeath, authorgender, fieldofstudy, countryid) FROM stdin;
    public          postgres    false    223   sl       Q          0    34057    authorships 
   TABLE DATA           C   COPY public.authorships (authorid, bookid, authorship) FROM stdin;
    public          postgres    false    224   �u       L          0    34022    books 
   TABLE DATA           K   COPY public.books (bookid, title, dateofpublishment, booktype) FROM stdin;
    public          postgres    false    219   �y       W          0    34087 
   borrowings 
   TABLE DATA           z   COPY public.borrowings (borrowingid, borrowdate, duedate, returndate, extensiondays, latefee, copyid, userid) FROM stdin;
    public          postgres    false    230   �~       N          0    34029    copies 
   TABLE DATA           A   COPY public.copies (copyid, code, bookid, libraryid) FROM stdin;
    public          postgres    false    221   W�       H          0    34008 	   countries 
   TABLE DATA           O   COPY public.countries (countryid, name, population, averagesalary) FROM stdin;
    public          postgres    false    215   ��       S          0    34073 	   librarian 
   TABLE DATA           6   COPY public.librarian (librarianid, name) FROM stdin;
    public          postgres    false    226   ��       J          0    34015 	   libraries 
   TABLE DATA           N   COPY public.libraries (libraryid, name, openingtime, closingtime) FROM stdin;
    public          postgres    false    217    �       U          0    34080    users 
   TABLE DATA           -   COPY public.users (userid, name) FROM stdin;
    public          postgres    false    228   >�       f           0    0    authors_authorid_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.authors_authorid_seq', 1, false);
          public          postgres    false    222            g           0    0    books_bookid_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.books_bookid_seq', 1, false);
          public          postgres    false    218            h           0    0    borrowings_borrowingid_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.borrowings_borrowingid_seq', 1, false);
          public          postgres    false    229            i           0    0    copies_copyid_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.copies_copyid_seq', 1, false);
          public          postgres    false    220            j           0    0    countries_countryid_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.countries_countryid_seq', 1, false);
          public          postgres    false    214            k           0    0    librarian_librarianid_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.librarian_librarianid_seq', 1, false);
          public          postgres    false    225            l           0    0    libraries_libraryid_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.libraries_libraryid_seq', 1, false);
          public          postgres    false    216            m           0    0    users_userid_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.users_userid_seq', 1, false);
          public          postgres    false    227            �           2606    34051    authors authors_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (authorid);
 >   ALTER TABLE ONLY public.authors DROP CONSTRAINT authors_pkey;
       public            postgres    false    223            �           2606    34061    authorships authorships_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.authorships
    ADD CONSTRAINT authorships_pkey PRIMARY KEY (authorid, bookid);
 F   ALTER TABLE ONLY public.authorships DROP CONSTRAINT authorships_pkey;
       public            postgres    false    224    224            �           2606    34027    books books_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.books
    ADD CONSTRAINT books_pkey PRIMARY KEY (bookid);
 :   ALTER TABLE ONLY public.books DROP CONSTRAINT books_pkey;
       public            postgres    false    219            �           2606    34093    borrowings borrowings_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY public.borrowings
    ADD CONSTRAINT borrowings_pkey PRIMARY KEY (borrowingid);
 D   ALTER TABLE ONLY public.borrowings DROP CONSTRAINT borrowings_pkey;
       public            postgres    false    230            �           2606    34034    copies copies_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_pkey PRIMARY KEY (copyid);
 <   ALTER TABLE ONLY public.copies DROP CONSTRAINT copies_pkey;
       public            postgres    false    221            �           2606    34013    countries countries_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (countryid);
 B   ALTER TABLE ONLY public.countries DROP CONSTRAINT countries_pkey;
       public            postgres    false    215            �           2606    34078    librarian librarian_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY public.librarian
    ADD CONSTRAINT librarian_pkey PRIMARY KEY (librarianid);
 B   ALTER TABLE ONLY public.librarian DROP CONSTRAINT librarian_pkey;
       public            postgres    false    226            �           2606    34020    libraries libraries_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.libraries
    ADD CONSTRAINT libraries_pkey PRIMARY KEY (libraryid);
 B   ALTER TABLE ONLY public.libraries DROP CONSTRAINT libraries_pkey;
       public            postgres    false    217            �           2606    34085    users users_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (userid);
 :   ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
       public            postgres    false    228            �           2620    34112 /   borrowings after_insert_update_late_fee_trigger    TRIGGER     �   CREATE TRIGGER after_insert_update_late_fee_trigger AFTER INSERT ON public.borrowings FOR EACH ROW EXECUTE FUNCTION public.update_late_fee_after_insert();
 H   DROP TRIGGER after_insert_update_late_fee_trigger ON public.borrowings;
       public          postgres    false    230    233            �           2620    34109    borrowings setduedate    TRIGGER     x   CREATE TRIGGER setduedate BEFORE INSERT ON public.borrowings FOR EACH ROW EXECUTE FUNCTION public.setduedatefunction();
 .   DROP TRIGGER setduedate ON public.borrowings;
       public          postgres    false    231    230            �           2606    34052    authors authors_countryid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_countryid_fkey FOREIGN KEY (countryid) REFERENCES public.countries(countryid);
 H   ALTER TABLE ONLY public.authors DROP CONSTRAINT authors_countryid_fkey;
       public          postgres    false    3231    215    223            �           2606    34062 %   authorships authorships_authorid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.authorships
    ADD CONSTRAINT authorships_authorid_fkey FOREIGN KEY (authorid) REFERENCES public.authors(authorid);
 O   ALTER TABLE ONLY public.authorships DROP CONSTRAINT authorships_authorid_fkey;
       public          postgres    false    224    223    3239            �           2606    34067 #   authorships authorships_bookid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.authorships
    ADD CONSTRAINT authorships_bookid_fkey FOREIGN KEY (bookid) REFERENCES public.books(bookid);
 M   ALTER TABLE ONLY public.authorships DROP CONSTRAINT authorships_bookid_fkey;
       public          postgres    false    224    3235    219            �           2606    34094 !   borrowings borrowings_copyid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.borrowings
    ADD CONSTRAINT borrowings_copyid_fkey FOREIGN KEY (copyid) REFERENCES public.copies(copyid);
 K   ALTER TABLE ONLY public.borrowings DROP CONSTRAINT borrowings_copyid_fkey;
       public          postgres    false    221    230    3237            �           2606    34099 !   borrowings borrowings_userid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.borrowings
    ADD CONSTRAINT borrowings_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(userid);
 K   ALTER TABLE ONLY public.borrowings DROP CONSTRAINT borrowings_userid_fkey;
       public          postgres    false    3245    228    230            �           2606    34035    copies copies_bookid_fkey    FK CONSTRAINT     {   ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_bookid_fkey FOREIGN KEY (bookid) REFERENCES public.books(bookid);
 C   ALTER TABLE ONLY public.copies DROP CONSTRAINT copies_bookid_fkey;
       public          postgres    false    219    3235    221            �           2606    34040    copies copies_libraryid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_libraryid_fkey FOREIGN KEY (libraryid) REFERENCES public.libraries(libraryid);
 F   ALTER TABLE ONLY public.copies DROP CONSTRAINT copies_libraryid_fkey;
       public          postgres    false    221    3233    217            P   *	  x�uX�R�:\K_��	�o/y5�K��L=q7�,�
\�G��'���\`"�T`�Hy�d�,�7�U��ؽh�D��U������}��9�~�N��%1��oٶZ�J�5Joj<�F�P���E�HV!�
f}׃��0vxi�cvQ��V��<��q�Jx8]��*������?l)�ʮSCpiL�ˆ����%JWa��b�����v^)�xʾ�k-��a��V!m1L�J�6=��<c�i�\7z�ځVZ��F�Ju�ݰ$�9��?�n��^���A���@���;���Y�t�|%�UT҃��9/q�^7*�����z��$�(������3�	!��A�Tp>v��hC�BĴ4�gw�F�\�st��>覯l�\QA�yD{��X�S�b�(�4��\w�S�GP�G���۾�`��AQ�\Pk��Y�(�"a����[9X��2:F\��);�5X$��=����b'1Q�"ľw�AS�Y���lUO,G����9�!��s��z��T�oV�ن�*���R�i�Ke�M��Hur����thKv�U���R���z�����a��4J8����Փ��ˋ�����J݉��2	vg��4�?�}.t]����;�x�o=��A5�n:�O|1>Q�1������!�.��V�ʷ�<�GSxh-K�w��
�t�Y��)L��� U�Sg^/)�c��)����u��]Hj'7[3���CTN�mlr+|"�7`�D9��U�R�5б�M6��+f�G	���v0���#������V�G��}W��	
���ƨM!�
�@�c9�Cvkh��j:��$���8�� ���R���qB�/��U
������N�k�w<+'5t�Of ��cv�a���3#��I�Gcyt&'� "�4;����W(�8e5Rw*�I�3�"9q�Q�?(2Lh�f]�n��f	ˎ�d�?��#�q� 5CM86͓�ʙfV�c��}>$<.P��%8�םy�����K` �1x"��*�����䵎����G�<	]tO��ZIk�$Y�A�:9�\������34xM )�2s֚~�]�2b����"2���"��s�%ʗ����&SG��#۾�6�۰h'TZ�"͍�{C�|�ؙE̓��W�!WZ�ŅU�����LMў�%����5������ol=�+�����	!�nl��ه��犃F<)ܙ�0�gSr�e��<)��3i��[Cg�C����4D��Za�L��Dc�茱�`7(0Wzc�V�����:o�V����(��D-E|܏��1��U� ��WYxi�ZZ�ށ�X�PL��$O��O�{�9<Z�4e;X�j�����i+�:�y��Ǉ_��VS�m:��B��2R����5�0�K��N�����8*8�ww�r��[�ی���b�%�W3vmpo�zl�.m_]b���/HlƳ��a����
n�ý x�� �`'cG�|�")89HiH������AS�E좙z��ȡ���V`�����,fg�����t�����G�.Y®�	9�	��֦p7U.09���'�28\�nk<�)��F��]Jp��D��	M����0�^ۡ�@CR�{FA���@�2�X��X��6���7�,����kT�]e���i���t�J9�mr���>��T�$Q{ha�K>��C�oaL3�����9���j�l;]ٍ�.~%�k��3�<����G�S�ww?�)�yd��&����o����1���C.$������1GT��C�b��k��z�Y���B���9�S���Iz�6}��?kw�q���l�rf8[�T�ߝcI&�W����(�a*��ہ����3��[��!�}���,�No��nDhxҪ��o_"[�H�y�l��bFB;������l��'R��b�#����U��.��R�=S��g9�J�	��)��ON�>��C^��"��PJ�ѻ@���S0ĝ��F�j��e���NZ�gN���J΋�nF4��%�ֺZ掲��2c�$�7�x��G��{臨U�8�n
N��+�s@�)<�-�G_hJ^c��A�xQ���tƋVB!m�����Q)b1�g�{w#K�p�r^��\Rʾ"�'�������ڶ0٥`HX2XgZ劈}t��<.y!�"��ڨG��E�?P��L���x�?;�w/#���4y��4V���#�ev��|g^;9y��1g���Ǣ�m��ke*i���֋��7H�X��[5>���a�F:_�]&�������W���y�ȎZʣ���e�2�l*�m]�W��<�}0��d�Hq��||z��;���|Z��\�!�m�-8���ǇT�k�w/�?���ӕ$      Q   5  x�mW���6��>�E<���	<�r�3��wl㉀F��TE����d���|������~}|����Z.͝Z}.�jM���|���y��ʾ��"��XI�cIm�E��̑
ݼs�7՞Jy.��z�.��zZ;��ܷ��'��}ej�}��=W���`���~~A*ϗm$����T,n��E@����)ꑽ����v�Z�>�÷���4ш�>�D�Z��Bh	����s�ha�zw��S��G�G�����/={�����R��~Y)��P؂2��Dנ�F���ښ�=G)8�AYd��c�O�T]wI(����L��YZ���%	�����m�=�P8W<(F����y;;C���p�C]�>���%.7%��
��r��I_�"�87 |9@+d�,ҵ�ŕ��k�_�s�4��-��p��|fk��/Y��:P��p�l��@YY���7�I���W�t�f �T��3��wg�,A3���T{{n�$t5�W� ��01vT�B/8�_!}s�p�a�oi�=qOU�i	��s �����X�"��¸B��
���˅�f@cC:k�(����ƌ8
�ĘTn&༜����5Co�>���9�-�=���
ݚ�\�*O�4���@=�\Q.Z��D	W�1>����2շg#�h|��4�\][�56�:�L0LUN��u^�ʁ� ${����ul��Z���r�8�3$:]�X:�ҩ�K�Š/N9�qw��Z��r�x�-.:�Rv�E@-������tz)��f(�y�?�/"���E�6�h�<��(Sm���7gFm"�i��(:M��pM���	����[XG��!nH��@�0%�PuP-���`������/�F��ϲz8���=�+[��1��lC1bs�x�uD�I]l�f���~���������`v��K	c�:Ӝ�:)0Z�����{H����lYpfyҁ�ZV��F����V��Qg�Ug�NF��[�S��8�Y<������8h �C��%����QG�je�Uݲ�7G�76Ģ�����ه�u�0�������Ā�b      L   �  x�mV�n"9|6_��^���0&�ͬ�/N���46���e�~똆v�#�H-�r�NU�l�+kvu^)�ye��89�;���$���c�������ｄm�'��杯�ҕ�{Z�e�(���v��.��ԯ���-~���ԧ�N����(��t1��]̱!c��M��Ү�J��	Pfoű�M�8��(����d���ހ��y�ΡtQr|`�ယ��|}�
��4�Q�g���l�Y<�,{C�U!(+w|�Q^����~ǦV �_�"����W��~L[Z�#6���U@�n,�{����A?��~�~�6����̛�'��Jh�*�����X�3�,�G��U��G�-�� ��V;٠N�'�q̾���+�+�3EgJ�� \GI�w[_���u?-�8e?j����W2/���s,!�k8���A�A��oB����_��wܧv��Q;��TVTre�hOv���!��ñ�"�!���Z���v>�޴��������|JZ�أU��G�Ij�%и٧)k�A��;��lV�u��}��ҕ��E.~�@��G-]�E$����QwUۋ(����(�QT⊱��ԋ(�R��,d�z<ˍ6�k�q@�qu�9w�XqAS��$��Mv��8o�s� �6/�2l�P��'��/�@������|\���V�&!�Z�U@ŀ͕ƭ��Z�u��09.�H�]^�l)��{I%X��간�OBV�B��Uy���Ȥ#�L*k����a7NSCV��.�$���ONY�����T�x���@���!}�5�Q�	q��s��]#Tv�H�mJ�_{���Ar�>8y���7H^71C2k;<�D�96"A�վ�.�Rt�{e���.��U>B=iu���#���G����ȿ��7c>�VIo�F:d�B��Qy���<���at%G��K����zF�k���J�:? �GUXS2c�'�}���,A���>>�^�>��Vʝ9\�h���i��-�6C�~�t��O�Y��^�l�����Y
'�R8���ƨ.;�&�0�R���q�=��i�))|M�f;����qz��\Y$�u\�u�~Z����upcHN8c����rV��f�s1�Gv�&o� ��{+WA��3,`�65 /'���P8H��B���+٘-%2��A(D�=RX�w%~£��ޤ��³�/^��'��H��k|ܾ=�������kW      W   c  x�}XK��8\[w�
!��.s�st�,�E�面�X�$	��V[�P���G�T��x��C�ԧ���X��ZK;R���a��Q�����0���Ww\"�%]�k�}�^������:>�ܗz�ױh�ܪ�٣������+5���Uf����G��1���r�h�G�Bû��G�<{��@9:�.�6�Om�C�H<6�c�fc}1�4)T#��_�0�T���3��[~I�Kp�[U�!u�-���O�V�x�I��,�p���{���%��P<�����J-X��Y���w7�@�+����]�|�}�(��)y�W`���o}��c�N^R���Q!���/��s�2�Xl\�@K��|T�:..�F�#�����̭Ťn]_����[p�j�,�yѻa���H��G$T��S�p�J�����(����X���^�zI�Rd�k�#&Xis!ǂ��C�h ��Y�&g�J_Z��
#�@�r@�Zo�{=�U�n�T��v�wM�)qWǶ�%\#�M*�Jm�;դ��Yq��p��� ����]/Lq�-�=�G��bZ�6!�-j�$?l��01 �C<�Mf'����3ekbo��p��Y�p��$y+R�]k��@� ��4��W��%����^�V�!�uk����V��V�6R�p`���q�u@�nX	�&)=��[q����s)iW�7����#�PT��^�L�cs�r'�R���ݵ�{4Ghƅ�h�qK�ť�X"!�+���[]����$q4�72��B��I�����zZ�*ݤ����*8���=[�)�#�������l�r���1�͑���_U�4m�#�`ꈜ,�����+�"�8����6?��7ꥌ��_z�k�9�Ҍ,#ڼg�d�0�g�Z:��{W���S�*�~��q���,�D�l�6�e�-����'6O�� o�G���� �s˰	dD�S����Ljx�I#䇮@�^7bHe���aP�@cU��ye��/�q�B6=��[ʌ>Rc�nq|UX+�,8���\ȗ��
RG�2�����)Y%�ta��iĻ��9�3-�?���f�1���bGG�������{�'�+���f�mP�~�͔�s�۾��Nӕ-S���N��D����P&���fu���&��ǖ��1��'�c��<B��夅"����0Ya2O�6@���#���MY?�FX��p�L���S���XG������0��m�+�v�h�XN�n4�ĆYjE%q�d�%9NR�Ml�ܒ�qMS��]J[�W�5�'�x�򼝦/6���܊�Nu���B��.�FI���e�]>v�4JY�����o�L��z(��l�:�^vl}��ibҤ������FO����u�<n*;^�äQ�̨�Q1���9����:���,��noK�m70�c^���F��0T�N���w
����2����\$��}|�����-0hQ\iH�q�W'��H$My��ּ/�_ȗ��a�́�?6�&+
E�:J���y��*�H�X~|�Ib��F��ֆ%u�#��H���/i+©ȿ�{9��g*F��"�����[�A�*�� 5�������6c��g�����?��Wk      N      x�M�I��6D��^^��^j��p� ���N�$� �@ |��=��+;?�=���齬�k�>�=��O�z"�ڟ���ަ��~���?>m��iS��cO]O��xr�u��X<��;�T���T�L}��j�Wwy�Sһ��R�<O�7�g�55��4��oΚ{�_�e���7�g�����<OKo��5/�^:_������Y���xjz�bRK�x�_�����������@y>��ͧ�?hQ��v�����,�k���O�E/�oIm�����^��9$4���'͕��Y��-��d���ܷw�Ѯ�Оb��|��j�����$;=5��z�Zg,�ͷ̧�9�/��O)��ٛ���y}J��􌤩N�d3z�t�� -�Y��Z������j'��t�sd��$w+����g/ҕ6���I��SS/fF�Tn��kmvN��E-��,���Hv�z�g*��cj�Hn֩ܺ�~�M*1R҄�j+hb�z�,:�>г�j<I�T���!>ɢ4�Gk/��Mk�պ~�K2	�k_�/��8z}J���>�x���e[ʗ����֋�}���	q�e����ҁ�ü_M&��ޒ�2'�73�C��{j���,y���D[�i���M����P�X�YpbI��c�@��]���{e��t�����t�{)]�T�Pe�R�T�,%LG�Dz���T�P֌�w�Z�i���~�w���ǆ֒g��}vbu��I=֥Z�;��&]�mo,U�U��Nf	׫�+�'�.%V�-Y˰d����f�u�Њ�5�ֿZο,��w%���I�.�H��R��Q���L���R�N{�%�]��Nް�tZ����,��?��6}L�lǚ�1���Yi��$�H6��l��$�mf�ᮽ����.MT�t�IS_�i�%o�P�u��U�L��ay�^��%q�땣=q�	��.i��i����ޅ�f���\&�\�W�i�ZǰKA�ӣ�9�9���+ײd�;�Ȯe7}מe�	�c��hR���\�Z��&�_�*�P]�Nbws5�Ұ��C2&� �Ir��O��&��v���i�5�ﾲ˾��}S_'Ԥ����C�Z5��\�6,�KdY;�N��+��$�cwm[���:�Z$5>�������Nx��c���;G��8Q��]�̃�&L�:��ՊlBӱs��GS�W(h�"+�'�93b%JQ�r�L�o/桳'����gL.(���cٞ!�j#��<׏�*�F��>�[��b
��9���Y��T�H�����-J�<K���Ǥ��s:�\P)VX�Hٲbt��XG�[c�Jɥ��8�x3!8���9-�`�c0��,�. B .���j����uJ����N"s.�Ѥ�e�,2k�r�C.��tk��s�tV���Ɋ�E-EJbg�'����j�}�?�9$b��ːe�a?����&�^.Z M��C/��շ�8�?�Wxwu�	˝`1ͥw��y2C-�>�.oG,4_�:�M�����X��0%�nӾ~��l�l�h%�n����QKE焖�E� Q�$:=����A��O��63q�<�k@<��FF�+�h ��K��A�q�٦D����O�A�����+�=���Nd�T�f� mWq��2� }Hժ��: ��Z~��gK�eTN�����+��z���� b��" ޼�� B�"��F�[a�
�I҄!U�e���¿r'2h`�죢�2�L�D���zƏ�_��(VK}�e*f�&�o�N{��bH��� ��싽Z��B�6�m��B�+C����CS�J&����"sl����2"�6@��.P�zZ�'��`i���E���6�^0�yժ�����tZ
u\#x��ӾܾIg����"�Ud��b��V#��W- w#�'�C�!�3J}�X3�";i�b+�?���f,��:d^CK�����$l��։\(Sd<�u��gr�R�'��WuBr���`P�y�v���9xO��6��pV$�E�����R�3&f��Ѷ��=o��!�0E�0��ˬ �]���hޕ��OP��W�/rD�$�l�(�ܸ9�/�c!�6��o���]y-y`e�XP�s��@��U�H�wͫ�,�i%}Q��T�4�U��ð���}���-%�A=&���RG^H��0M���X �RF�"|� ��|�݊N��)�)C�������tO�ė��B/@S���*��|�;v�f|cҪ���`�wQ�d;9�cx�>x��82���d�i�������s v��p�Z)��Vص�c5$���u�⍐P����$˥��dGw9�BR-[�b�q,��)È�Q:$�L[�C��mHJ҂I'cչ0�/���WςT��"�;s�,�$cJ�W�F��qrk9�T�5v��@�W��>ޕ��9.��T\9~�3�*K��M  L�1!4�aEv�ch�� j���~�R!��f�\�����4��q���؅ٖ�^8�Ƴ,�~��틺y��(8<þ�1���P��s�3%}�Ar�L�l�G�lB�����=���e}��d[I	81�����U{��b��5I��1��g���yG�*�a���G��B����|)w��5�eGqm�9���w��&ccƤ��{�R��0�D��2=p8��*�5�)#Rl�t��!�8�Fj��V�)��<H�'�%Ym�U�~n�a� ��#rR�b�,A�՚M=
�(8�v��<�S;V(H����2֡��m�&Q+�4�W±il�4��RC�ȵ G@)�<x��n�D�XW��q��d���m~�l��m!'l�؈���wJpz-
@�*�צ8>B�RɈX����
������B�-�Ȅ�؊��˒ĝ�o�q�|�~}4��|1�W����QG�����X�>:
����*|y貥�Y&�?'p:����ು��}�K�k"B�JG��M>���+Ό�fB�iu��B��Y2�B�[�����F0C*�0�!�ma%
ے�F	HrK.>^���
K	��<YԜFR2����D��2�&g�-� �L�P:��9D큼:x���8�~ӊ�8�C�٘�lZ�]�y&)�������|�b޼���*`Z2:m����z~N`�4�����������
U���/ A����0-��P
@ȏSi�3LF�4cI�+��+^�!�:V��v���җf��@?�t�I�G�ʖ��"E�4�j�[�0j��hM�/>W/3�=�#���w���x��2,;�K�l$i�5&Q�2��[�;N&ݲA	j\/���e-�Jp`�/�J*UoEB�$���-0��<������y�]2B�}R&3#�O�ғ�(s8~�+Rv�#I��{	B�ǼÞf	��o�y9e�OS��?�)Ƞ}�oY��������b?R���"孮8(Z=�\{8<e�C�����u#�fS��t!]��|�+~��Q�7ߛ'��5��($�f�v��qd\R1����_�V]*!�r��B|�2����R���2�Fxs(G�G
�x0��h�Y�Ix�i���R�
���l{H�CyII���<�i�� �l"���iiW%rK ��M'4I_+AcG�"�:r�Ѓ-��.Hx8�ǳp�n�$Y!�x<7��G)J|�_�L&�,
I���}8�@N,Uj��-�$0I���ax�p��eu�n!hÒ�п���F��.ǍL`��+z��U����w��)#Ѽ��n"I/���
�Õhs��Q%�x3���!X"�.^��P�W�Y8� w���va�||���"1HT������c3L��w�k:!�v��SWLaE<7N�(x|�Ae-�p4%�ޣ��S�h�2�'�q�*��v�� ,#����L^r��e	X�J��Bݴ���qw���u*+�o,ĩV32W<��={�/{��id�8���w|n_z��mo3�]T��J� �͸��Y�/%�.x��𱃊�oڜ���/Qو�>5y� ߙy|�:0s �n%@:_\�#�bF�c���	���ROݴ$C|!�K�9�k������<I`�٤+��_�k�¸6���vNq��/���
ޝ'�$W�p���<)�t�*1��+"�:(�<-�A-��L    ����U��R�W�cĉ�2���qC���Zu�w����t�Gs�[��L�E'���`�\�@��+Ĭ�EM�X��S�)�о���&Ul��l,��	�p(o��-'ʙwe�B��;����cr�^N���6�d�zI<`Q2nS��K?u�}x��w5�0�/h���~Y\�L	M0�^ܨ@�v=�|\Pv�ܼ�x���W��ZLo'G��ˁ��+H�c�q�?A7񘖤`�~ΐ������������u$W�7�'@Ҡ`� e�4����(� �H���z�R��h.�W����9�j����oR�r���� �����l�Yo\�m�A���<S\��ԖL�݄f�V��THOfm��$���R#�6��x��1�8���[��ٿ`�acH�&/�3�M1/*$�U2\��ҫd�h�K�"G��ӂ֪�!/v�Z����`a�ս��ʾ]!9f�(�EeY����D�^�Ej���Hm*d �e�-�"+��v3��n^2�A�v��g&�#�)�� �5��bz>䊫�t��k®��X=�)�i�:�m7�w�B 3W��b�3�Fd4K{y�C���ܒ\��Z։h��h�j�b�m���;A]��=N�MwP�P�D���.(9SPb=]d�ǈ����݆��Gs�a�O�m$�@6(�o��U3���e,B�6�]&���7PBr��B�wSS�i�%�3�����aN�����`2H�ys�t�ܥC� ���A����*�2��(C���SP��o��~��ꡏh���"U�owHWƠ���"�y`Ȳ"[�4���~�\/Æ�*���H��	7�s��l*�ks*�j̈́��5AO���X&#do��@�(CG�N@7y�`Im�j݅Kzѐ��Vo�0V��nT���-�T'#tp}�w{p�i%�jdU���d���*@��(Q�����t,݌�5�NH�$f�]�#�DwZ��L�
-��X�����e�QȪO��y��ś�4af'W���:'Ư�y�yh�!�o�ܼ��M��u���l˃�8E�*�Ic�c�r%�,ik4�<�٨a�Z���*�f�~���E7Sv>ߐ�.��1/�Ri�%���1r�0����]������ȗV��$v��=Fc��)�'�[7��qL]xǅ?���Y�Ϝﹷ���q�M���K�~�My�f��dY)��	k��#4$��|=G��ۮp� ��Qįn����u�F�����8�J�_9���]�.f۪��1èl�J�������pM;"�y=�{v�<o�w@Wc��M] KQ5�`�3�Ҩ���p���ct(eɥ!�]��Ӎ0�҂oZ�dC�j�"G1�PTM��u�I����2�Q+��ǹ^���V̗���#I�����<�Bˮ� ��N�LZ�K��,�b�5\M��޵D��jS'K�uLx���*>�h�R�~�x\#��m��]���<i0u��VȾo�@�Q��S� �q����t!ݽ�����-�����;��_9YС����e�<i�~��9��uM�C��k��u�	1��{��1	�Χ�̔\s��F;7+��>��W?�%#�⤚2[��H����AHwۉ#6=��84�e�=��� ��ݺ��=F�����f�n���f)i�&5�)�/x6�
��O�d�N&��@mor�t$��2V���l�e��|j�����lɐ�W���G�� �Tt�A}��Qƭ�V7�v��^��V��.�U��G�L�c)l�C�s�ܝPwK��|4���uJ0�^Up�Í�ʛ�@���nB&=/�̜,��"C�� )��-L=�;�<T�t����\i��q3�¬N,𧈎�|��x���%�fb��8N-;��v��I��&�W'���v���@��Fs����S�x�a������=���Zf�G�i��Xs�����$�B3�b����oQ� ���1ldnHŵrg_5�1~���a}�)��@�{�)���LFK&��B��D� �P��2�qwd���T�Ҝnf89kp���l'����(G��u�1�7�d��H�Q1+:�ͺ��M�'�����f�Ɛ�H��d�4DEjn��m+��j�k!5W�\�ؚ��t���>o8�ۮ �Xo3� 1�$�0z�>y�E����H>���{��yy'v��@o���IK��̰��,��W�(U������^\q�?t�GJR$��y��Ek�����e����\��;�k|�_����i��q[��ܝP ��#�?Z2Uh)�t��Ī��Y�-S�����O��q���Ncm���˩�쇶A�[]Z�Æ!2�i�l�oVw
(b�P1YM���n_���$�/��R`�݋&/�lx�BN�L�s�%�7�ʭqv:2�x��>�i�֘}����j4�g�څA�|{�sh��oi��v �~�0�����}�s������	;��[�4W�:O"yd(%2 I��s�f�d�F~8�mZg����.u��R���`=m~˅f_� �g���}���J�Կ��^�VN��l��8���8���]eӾl*}�7EׄnwW�$��ݐr1I.��l&�|��e|yk��tnR�9�b�ވ|����r;������U�n����j�5�ם?���YE�I�rl��7�$�n��ۤ�&�錑}�J�6������J�����)F�{֯�+�N��^v�WL������դ�����E�i���K�98&�\������:,��Q�u2(I����\�#���ެ��٠�|�*.11iy�=��븩vhz�ƶ�����@&��^j<��AUlm��D9G�����o��V��N�
�	�h.w��oGh{'�B8�r�k��;$b���Ȇ�ѻ^�d�w$r�+���i��M���<Dj�Ey��c֨��1��&����w�jU�G_N�<w˴$N������S���08��gD;햔�!����;?\���T���vp'���9.�H*.��xFQ�����ӠG�(�A2@i.m�I�ad��s{�����Xkl�+���9�̙��!�g�9|_�G漤U�$�+� �h>��v�����j3��֠�0�n݀d70�)8C�2i���S>W7�6NU��w���b6��Β�(]\گ�^��\[s��9�{h|�՝�3*�`���,ڶ��E�'��r�g����늒0�Kc�,� �/�}��r�S�ө�%���=�J((ϝ�钻w��GD�s�y�v�Ѷ�f����C¤�խ�}F����ݓ��:��۹�1]<'Lg3�s�SF���}�g���4?nb�਄��p���J���A�N���,RGc�\Sξ!ɹ�t�P�N�\���Z��o|s�vN&���e�_����Ԍu������滉�ޕ/*!YC$?������A t��k%�����^�sW��uG��������M�qur�zE��� �2#f5Z��G��-�xE4'�sʃ�q[�leh.j��?*R�E�u."M_&�V.ܵ���`�˖��M�7b�~.5���嫌#��ݣ�~�$�X*��u��|'���S�����}$���D�;�|p;Oeec�u�I�r֓l-��C�i?���2$��rt�B4w\��3��5Ԣ��K|�
�Go�r߆�Ts�y�PX�Eʾy�!�6n~� 	�����L���uZx�r����³���6�����u��/��O����Ii��9�}�u���N�qh����P �q����J�Q{�s�J?�H����_ڬ���G�k\թ�[�9ޭw����ĥqW���z�W����4<G�M����n:^�d��֪�oO�f9���x��n�����5P��JT?� 4�)X,�zH:�
S��͛}����׊F5s���np���;Y+d�8�AOn׻�ıƺ|#�$�_�ϏH~56��Ϣn����hi�����|85m�Es2?�,'��D��o4��%��F)0��ќV�߈v��W1�ѱ��c�����>8W�j���:�/�h��ekn&o���у��w��he~���6���N��ߩ�u���n��tbY�� ��ԭ��E\   /���
Vqָ�\Y�>�%`���Gj}�-�n��Hn��Ꮎ�E����t�fĔ�.����.����'�ȸ'�o��D+*���7�O,pS�8�k��;�5F�.��#|
�D�H�vm��dF��T�eS�X����3�Esz^�ģ���t��w�Xnν]5�(׷�0�������*����+"��7	O�t�o��Ќ�m%V`�#q�������u
��۝pQ��B3/�\h��v���=���/���8��4�k�BC��Tf�[���ɝ�MG�	�߸	�	�N��-�L ��[����-��L��7L���w)\�ߔC|�r�����-�>��/����*+�,�@�K���E�����k��WqR�+ĸ�ƴ�T�'S!@�-%x�b�5��:�Į�n��O]o�{�yE�Όݮv�L�e4�	x�Z���>x!I/��X��}G�����]׿�����S������/���j|Y�f��+��8��w�,�����Bv��!�ڌ�S�VKv�u�\o������zF����ז�	XD��%�g����tW-���������so~��ڕ+��/n�ؽ�C��Ht��O�%J,�d{s�!:H��{�<u߹�w�e��_r������w���؆$�|%^�w�}H3�¸~�}��{Ť[щ�G��]r��'���8#��6I0zu��_.��O��'Ho;�y�S>�.o* ����{܄���I������ۅ��od�WO����ф]��J�j��7E��PC�6�{����(����m��m�'���Ώ��ٹ3~������r Iw�73M/k̵�Z�7Zv��:�Λ�O�[���,����t��[���'v\3w���.����3�n�� ֽ�1��I#T �v9�����T�<8���8t�w"���:~�K��SQ#�[U�RQ�����2���jocw���NSf��`��.��ڻ}0�6ᐹR+�׃Q�fk��i����n�w�d}��)�rmB�c�����p�7*n�w�܆Ra_��b����}���      H   �  x�uT�n9=��B_0�R\��8�h�B��0�#q$��@u�#��f�����Ȫ�TI�Ͼ���i�W�V+e���Rje��T�D����Z�f,m�C`#>�FG/VLjz+m��x0�X9zL}:$�!��cr�����:�ԡ�q,#�W�K�/��Q�!ZaC���J�ԃ����k��C�[���� �X�]�jE�k���L�N�;~���pZ=לȡ�hha�PC���u��NP�8��;{7�k鏇���W���L�!u7H�h<�FQ;�]R�}pB$�$iOOy8�ڥ�p%���\|���S촸`�nX�c}�p���Ý���a��j�z�p��T�}�$O>�q�3�=O�`d�t��w�5�x��o-{�+VE/j�^�^�!#F��л��y ex����{t�3�<i��CY?��8�Õ�����U�Ч�`�*�&ze}:�.Xk�/皶��d����mD�I�ֈ���Jc�%����/5g̞Vl��?�GO���n�`�aM�Q��>��%�grA�n{�[��mJ�"�.�u���r���N�"�5.Z���1�)U��ܭX���y�y���Y���ZS�&��Wn�����L�2;l�BQ�[�kf�s쏩�H�WX>ҍ;�\�V�9V�9��ޞ�0S%Z|PBf.��-�O���2������9s��?v鐯'4b�d�f;�_��4�� �e윢mz.�+ӣw������1�      S   g  x�%S�n1}�|A�^��$!
䢐�R՗aw؝bl���l��c�f��s�\\��4��qc�MjzSw�~�kٙ
�Ab�_R�M wkw4|��93�[��[����_�~*�w��h��J)	.co�u��=��G��Yk��>��QM1����?'��v�q;(����|`JV�,�2;�9�uP+��$���Bk�)�]����p3�{��*���J%�*�)8��7�D_r�u�>����@����JL9�Uq_-S��,`�b��q�.�R��:���S��ek�,jp�|MY�3%����<�r
:X!��Ù]c�Y̫��ދB�aOc`5.ZߜLy�[}���);].26�b��ı�t�H���t�*��ܨ��N�:��*�?��i�a����u��1��*�>��;}�L5UςY)7>�m���U2��� ]��簶c˸���z���;�
Ҷ�n�>O�i��d�	�$��v��c]h��W�9��V���>Hj2n���t�>�9t�Y]k�B��F�jf�HSxZe�����5��R�Zݿl���W����М4������X�kWyA��':*$.���0��c�|*      J   .  x�u�ݎ�0F����	��'@�k���E�ەV�1`����8E��7aԌ	$_|���8��u����/�h��^�I��4m~�v����+�ڶ鵒�j[�V���y�tQN�lC�m�ч۶4���.+�w�{qFiG[%���m?ʷm�~��"�H���[�yw�1Y��Ӏn�3�u�.�	y����7��Fu+��h��.��;����)T�f׮��jz�ɭ���7�`�)�� w�R:L�p>���s;W7��"���RVaH�0���XD�f�X�#�G��`:G'����
�7;�1�Tv޾W��񯲵B2��kmA;�`d��d@�J�`d@�OY�
��2,��6вm&Rɀ`d��g�Ybs̀�_�
������]�@�VQ�����0�pR�\�<�Kg��'���aO#P�S^�O*B�+m�<�.r�e�~C�"Z���'#�*e�P ��K�Zk���͗R�bs-��Es!K����5kg�� ?���h�B����ou�@�$"��~>]a�-�{���H�|�*����!I���%�      U   �  x�5UMW�8<K�B�=����>�0�a����Ҷ{bMd�'�a̯�����H��U��D�Ο�����0�=��L�y<:���ݰ�Ė�Ѭt�2;��,V�Æ<����F�@^Ӡ�y��=Y�W
�� �eK�g�e%���uO��Q��r!kվS;��[و��NʟٜH&Դ�yuK�k�L�H��� �I
�$�����L�'�un��`��<����>�7�L
j[@=ϭ��]&��.>R:LL=nU�e6&���Z�<�x�2{��Z&�8�8�AE?��t�	:jcd���۠I=����O2��}Ѷ�L젪��^�~c��šs�9����X�Rw�-,�R��7��f>�~Zula�v����eZ�=���?��R$=�@�����D�4*�=`Zf�@:��(ym(��Ff����읺rt� �L\����hI��'=����ؓ#G�2"���C�F�U��ز��ڹ�D�>��0��"Guňc TF<1R;��gw�F�:��CT��'��A"_<8�B:����<���LP_(L�>�#�	�y�i@e^ Đ�y@T�%z�z��8:�J|AH1;؇�:v�uG
'5�ҍ�sf�!5܊�x�gB���;��"A�d�z�?>�,~�Y�Ш�+�L�h��1��z�{�w�$�\\X�v(�Ou8�~%VQ�)�bC(�kf'����ƶ��8����_���'�S�Gt]4�#�4�=#7,��ĭ���q��e"��Q[����"�Ӈ,Sq	6j?w��d�EV?`'�Bׁ��bW �C�)fe�x���tYD�q�Ƒ�ʖ��q:���V�/���a��2x��hɲ�s��j��O1�e��� �Aq���#T;8tS!+���b��JA�P�_����U&=�I��AV9$҈�օ���@=�;8��U)�9�u��V
T�M3�R�$[���æe��nM��u��h߯q�Ҵ�:��9|��8���_��d�O�E]`�L�L�1��~l ���8�ʺ�Rq���> �u{��rc��]�=��w������ǹ���f��g��q�d���Xj������lRq'��ua����ߗ�n��&�.�9{%s28���%�?`ٔ�(P����c�:�`�`C�aԗM-vx�Ea=�Z#�i�I=�����w
��-38�#ֽ��/)�/��F�     