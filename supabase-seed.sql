-- Opțional: evenimente și premii de pornire. Rulează după schema.sql.
insert into public.events (title, category, description, points, min_level, event_date, place) values
 ('Sesiune de informare Erasmus+', 'Mobilități', 'Afli cum aplici la un semestru într-o universitate parteneră din UE.', 15, 0, '2026-11-04', 'Aula Magna'),
 ('Schimb transfrontalier România–Moldova', 'Mobilități', 'Program scurt de învățare alături de studenți dintr-o universitate din România.', 40, 0, '2026-11-20', 'Galați'),
 ('Mentor pentru studenții din anul I', 'Voluntariat', 'Ajuți colegii noi să se orienteze în primele luni la UPSC.', 30, 0, '2026-11-01', 'Toate facultățile'),
 ('Voluntar la Ziua Porților Deschise', 'Voluntariat', 'Prezinți facultatea viitorilor candidați.', 25, 0, '2026-11-14', 'Blocul central'),
 ('Consiliere în carieră și CV Europass', 'Carieră', 'Sesiune individuală: CV, scrisoare de intenție, interviu.', 15, 0, '2026-11-10', 'Direcția Studenți'),
 ('Club de lectură „Ion Creangă”', 'Cultură', 'Întâlnire lunară cu un scriitor invitat.', 10, 0, '2026-11-06', 'Biblioteca UPSC'),
 ('Campionatul de volei al facultăților', 'Sport', 'Reprezinți facultatea la competiția internă.', 20, 0, '2026-11-18', 'Sala de sport UPSC'),
 ('Conferința științifică a studenților', 'Cercetare', 'Prezinți o lucrare și primești certificat.', 40, 0, '2026-12-05', 'Aula Magna'),
 ('Atelier de scriere de proiecte', 'Antreprenoriat', 'Înveți să scrii o cerere de finanțare.', 25, 0, '2026-11-25', 'Sala 210');

insert into public.rewards (title, type, description, cost, min_level, stock) values
 ('Sticlă de apă UPSC', 'Produse UPSC', 'Sticlă reutilizabilă cu sigla universității.', 40, 0, 50),
 ('Agendă UPSC', 'Produse UPSC', 'Agendă cu calendarul anului universitar.', 30, 0, 80),
 ('Tricou UPSC', 'Produse UPSC', 'Tricou din bumbac, la alegere mărimea.', 70, 0, 40),
 ('Umbrelă UPSC', 'Produse UPSC', 'Umbrelă compactă în culorile universității.', 90, 0, 25),
 ('Hanorac UPSC', 'Produse UPSC', 'Hanorac cu glugă și sigla brodată.', 180, 1, 20),
 ('Invitație la Gala Studenților', 'Oportunități', 'Loc garantat la gala anuală a studenților UPSC.', 60, 0, 30),
 ('Curs de formare cu certificat', 'Oportunități', 'Loc la un curs de competențe digitale sau soft skills.', 100, 1, 15),
 ('Mobilitate națională', 'Oportunități', 'Vizită de studiu la o universitate din țară, cu transport și cazare.', 220, 2, 6),
 ('Mobilitate internațională', 'Oportunități', 'Loc într-un schimb în străinătate, cu selecție finală pe bază de dosar.', 300, 3, 3);
