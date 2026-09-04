-- ============================================================
-- Zameel Demo Dataset
-- 30 demo accounts + 15 public posts per account (450 posts)
-- Also creates demo stories, clips, follows, likes and comments.
-- Demo password for all accounts: Demo1234!
-- ============================================================

begin;

create extension if not exists pgcrypto;

do $$
declare
  instance_uuid uuid;
  demo_id uuid;
  i integer;
  j integer;
  post_id uuid;
  names_ar text[] := array[
    'أحمد العبدالله','سارة الخطيب','محمد الزعبي','ليان الحسن','عمر الرواشدة',
    'نور الشديفات','يزن المومني','جود العجارمة','حمزة النسور','تالا بني مصطفى',
    'رائد القضاة','ريم الشرايري','محمود أبو زيد','دانا العبادي','سامر الحياري',
    'ملك الطراونة','علي الحوراني','لارا حداد','باسل الرواشدة','سلمى النجار',
    'فارس بني ياسين','جنى العمري','أنس الزعبي','ميساء الشوابكة','كريم الحمصي',
    'رؤى العساف','معاذ الحسبان','سارة بني خالد','إياد المجالي','هديل البطاينة'
  ];
  names_en text[] := array[
    'Ahmad Alabdallah','Sara Alkhatib','Mohammad Alzoubi','Layan Alhassan','Omar Alrawashdeh',
    'Noor Alshdeifat','Yazan Almomani','Joud Alajarma','Hamza Alnsoor','Tala Bani Mustafa',
    'Raed Alqada','Reem Alshrairi','Mahmoud Abu Zaid','Dana Alabbadi','Samer Alhayari',
    'Malak Altarawneh','Ali Alhourani','Lara Haddad','Basel Alrawashdeh','Salma Alnajjar',
    'Fares Bani Yaseen','Jana Alomari','Anas Alzoubi','Maysaa Alshawabkeh','Karim Alhomsi',
    'Rua Alassaf','Moath Alhasban','Sara Bani Khaled','Eyad Almajali','Hadeel Albataineh'
  ];
  types text[] := array['text','image','academic','question','text','image','video','academic','text','image','question','text','image','academic','video'];
  ar_topics text[] := array[
    'مراجعة سريعة للمحاضرة قبل الاختبار 📚',
    'جلسة دراسة في مكتبة الجامعة ☕📖',
    'سؤال في مادة البرمجة: ما أفضل طريقة للحل؟',
    'عرض كتاب جامعي بحالة ممتازة للبيع أو التبادل 📘',
    'فرصة تدريب صيفي لطلاب التخصصات التقنية 💼',
    'تجربة اليوم في الحرم الجامعي 🎓',
    'ملخص مهم من محاضرة اليوم ✍️',
    'نصيحة لتنظيم الوقت بين الدراسة والعمل ⏱️',
    'إعلان نشاط طلابي مفتوح للجميع 🎉',
    'عرض من متجر قريب من الجامعة 🛍️',
    'من يعرف قاعة المحاضرة الجديدة؟',
    'مشاركة إنجاز أكاديمي شخصي 🏆',
    'كتاب جديد وصل للمكتبة 📚',
    'مشروع تخرج: نبحث عن زملاء مهتمين 🤝',
    'لقطة قصيرة من الحياة الجامعية 🎬'
  ];
  en_topics text[] := array[
    'Quick lecture review before the exam 📚',
    'Study session at the university library ☕📖',
    'Programming question: what is the best approach?',
    'University book in excellent condition for sale or exchange 📘',
    'Summer internship opportunity for tech students 💼',
    'Today on campus 🎓',
    'Important notes from today lecture ✍️',
    'A tip for balancing study and work ⏱️',
    'Student activity announcement open to everyone 🎉',
    'Offer from a nearby campus store 🛍️',
    'Does anyone know the new lecture hall?',
    'Sharing a personal academic achievement 🏆',
    'A new book arrived at the library 📚',
    'Graduation project: looking for interested teammates 🤝',
    'A short clip from university life 🎬'
  ];
begin
  select id into instance_uuid from auth.instances limit 1;

  for i in 1..30 loop
    demo_id := gen_random_uuid();

    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    ) values (
      demo_id,
      instance_uuid,
      'authenticated',
      'authenticated',
      'demo' || lpad(i::text, 2, '0') || '@zameel.demo',
      crypt('Demo1234!', gen_salt('bf')),
      now(),
      jsonb_build_object('provider','email','providers',array['email']),
      jsonb_build_object('name', names_ar[i]),
      now() - ((31-i) || ' days')::interval,
      now()
    ) on conflict (id) do nothing;

    insert into public.users (
      id, email, name, university, college, department, profile_image, role
    ) values (
      demo_id,
      'demo' || lpad(i::text, 2, '0') || '@zameel.demo',
      names_ar[i],
      'الجامعة الأردنية',
      case when i % 4 = 0 then 'كلية الأعمال'
           when i % 4 = 1 then 'كلية تكنولوجيا المعلومات'
           when i % 4 = 2 then 'كلية الهندسة'
           else 'كلية العلوم' end,
      case when i % 3 = 0 then 'قسم علوم الحاسوب'
           when i % 3 = 1 then 'قسم نظم المعلومات'
           else 'قسم الهندسة' end,
      'https://i.pravatar.cc/300?img=' || ((i % 70) + 1),
      'student'
    ) on conflict (id) do update set
      name = excluded.name,
      profile_image = excluded.profile_image;

    for j in 1..15 loop
      post_id := gen_random_uuid();
      insert into public.posts (
        id, user_id, type, text_ar, text_en, image_url, video_url, likes_count, comments_count, created_at, updated_at
      ) values (
        post_id,
        demo_id,
        types[j],
        names_ar[i] || ' — ' || ar_topics[j] || ' #' || j,
        names_en[i] || ' — ' || en_topics[j] || ' #' || j,
        case when types[j] = 'image' then 'https://picsum.photos/seed/zameel-' || i || '-' || j || '/900/650' else null end,
        case when types[j] = 'video' then 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4' else null end,
        ((i * j) % 37),
        ((i + j) % 9),
        now() - ((i + j) || ' hours')::interval,
        now()
      );

      -- A small deterministic set of demo likes/comments.
      if (j % 4 = 0) then
        insert into public.likes(user_id, post_id)
        select id, post_id from public.users
        where id <> demo_id
        order by id
        limit 2
        on conflict do nothing;
      end if;

      if (j % 5 = 0) then
        insert into public.comments(user_id, post_id, text_ar, text_en)
        select id, post_id, 'منشور مفيد جدًا 👏', 'Very useful post 👏'
        from public.users
        where id <> demo_id
        order by id
        limit 1;
      end if;
    end loop;

    -- One active story per demo user, plus a second story for every third user.
    insert into public.social_stories(user_id, media_url, media_type, caption, audience, expires_at)
    values (
      demo_id,
      'https://picsum.photos/seed/zameel-story-' || i || '/900/1200',
      'image',
      'حالة تجريبية من ' || names_ar[i],
      'public',
      now() + interval '24 hours'
    );

    if i % 3 = 0 then
      insert into public.social_stories(user_id, media_url, media_type, caption, audience, expires_at)
      values (
        demo_id,
        'https://picsum.photos/seed/zameel-story-' || i || '-2/900/1200',
        'image',
        'حالة إضافية — يمكن التنقل بين الحالات',
        'public',
        now() + interval '24 hours'
      );
    end if;

    -- One demo clip per user so Clips has real playable public content.
    insert into public.clips(user_id, video_url, caption, duration_seconds, audience, likes_count, comments_count)
    values (
      demo_id,
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      'Zameel Campus Clip — ' || names_ar[i],
      30,
      'public',
      ((i * 3) % 40),
      ((i * 2) % 8)
    );
  end loop;

  -- Demo follow graph: each user follows three others.
  insert into public.follows(follower_id, following_id)
  select u.id, v.id
  from public.users u
  cross join lateral (
    select id from public.users v
    where v.id <> u.id
    order by md5(v.id::text || u.id::text)
    limit 3
  ) v
  where u.email like 'demo%@zameel.demo'
  on conflict do nothing;
end $$;

commit;
