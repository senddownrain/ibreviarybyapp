# Значкі катэгорый малітваў (`iconKey`) — Flutter

Той жа кантракт, што ў вэб-праграме (`mybrev`): захоўваецца толькі `iconKey` — адзін з 48 стабільных ключоў.

- `lib/constants/prayer_category_icons.dart` — спіс 48 значкаў, подпісы, групы, allowlist, дэтэрмінаваная падказка (`suggestCategoryIconKey`).
- `assets/category_icons/` — `catalog.json` + 12 аўтарскіх SVG; ствараюцца экспартам з вэб-рэпазіторыя (`npm run sync:category-icons -- <шлях да ibreviarybyapp>` у `mybrev`), уручную не правіць.
- `test/fixtures/prayer_category_icon_vectors.json` — агульныя вектары падказак (тыя ж у Web-тэстах).
- `lib/widgets/category_icon.dart`, `category_icon_picker.dart` — адмалёўка і выбар («Значок катэгорыі»).
- Асабістыя: `UserCategory.iconKey` (Hive); старыя запісы без значка атрымліваюць падказаны пры першым запуску і захоўваюць яго; перайменаванне значок не мяняе.
- Глабальныя: `iconKey` прыходзіць з bundle/абнаўлення кантэнту як ёсць; да запісу ў Firestore паказваецца падказка па назве.

Скрыншоты (iOS Simulator, iPhone 16, рэальная зборка): `ios-*.png`. Тэмы: светлая і цёмная; марыйная тэма на прыладзе не здымалася.
