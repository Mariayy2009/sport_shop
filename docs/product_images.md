# Картинки товаров

Картинки кладутся в `assets/images/products/` в формате JPG с ТОЧНО такими именами.
Фото из макетов Figma экспортируй оттуда (Export → PNG 2x), остальные можно взять с бесплатных фотостоков (Unsplash, Pexels).

Если картинки ещё нет, приложение не упадёт: вместо фото будет показана заглушка (этап 7).

| Файл | Товар |
|---|---|
| `volleyball_uniform.jpg` | Волейбольная форма |
| `volleyball_knee_pads.jpg` | Наколенники волейбольные |
| `volleyball_shoes.jpg` | Кроссовки для волейбола |
| `volleyball_shorts.jpg` | Шорты волейбольные |
| `knee_brace.jpg` | Фиксатор на колени |
| `mikasa_ball.jpg` | Профессиональный мяч MIKASA |
| `mikasa_backpack.jpg` | Рюкзак Mikasa |
| `running_shoes.jpg` | Кроссовки для бега |
| `running_tshirt.jpg` | Беговая футболка |
| `running_tights.jpg` | Тайтсы беговые |
| `running_belt.jpg` | Беговой пояс для телефона |
| `sport_watch.jpg` | Спортивные часы с пульсометром |
| `football_boots.jpg` | Бутсы футбольные |
| `shin_guards.jpg` | Щитки футбольные |
| `football_socks.jpg` | Гетры футбольные |
| `football_shorts.jpg` | Шорты для футбола |
| `football_ball.jpg` | Футбольный мяч Adidas |
| `goalkeeper_gloves.jpg` | Вратарские перчатки |
| `sport_tshirt.jpg` | Спортивная футболка |
| `adidas_pants.jpg` | Штаны Adidas |
| `gym_shoes.jpg` | Кроссовки для зала |
| `kettlebell.jpg` | Гиря 8 кг |
| `dumbbells.jpg` | Гантели 2 × 5 кг |
| `water_bottle.jpg` | Бутылка для тренировок |
| `basketball_ball.jpg` | Баскетбольный мяч Spalding |
| `basketball_shoes.jpg` | Баскетбольные кроссовки |
| `basketball_uniform.jpg` | Баскетбольная форма |
| `swim_goggles.jpg` | Очки для плавания |
| `swim_cap.jpg` | Шапочка для плавания |
| `swimsuit.jpg` | Спортивный купальник |
| `boxing_gloves.jpg` | Боксёрские перчатки |
| `hand_wraps.jpg` | Бинты боксёрские |
| `mouth_guard.jpg` | Капа |
| `karate_kimono.jpg` | Кимоно для карате |
| `karate_belt.jpg` | Пояс для карате |
| `yoga_mat.jpg` | Коврик для йоги |
| `yoga_block.jpg` | Блок для йоги |
| `yoga_leggings.jpg` | Леггинсы для йоги |

# Картинки видов спорта (плитки на главной)

Папка `assets/images/sports/`, формат JPG, квадратные (например, 600 × 600).
Пока файла нет, на плитке показывается иконка вида спорта.

| Файл | Вид спорта |
|---|---|
| `volleyball.jpg` | Волейбол |
| `running.jpg` | Бег |
| `football.jpg` | Футбол |
| `swimming.jpg` | Плавание |
| `boxing.jpg` | Бокс |
| `karate.jpg` | Карате |
| `basketball.jpg` | Баскетбол |
| `yoga.jpg` | Йога |
| `fitness.jpg` | Фитнес |

# Источники фото, добавленных позже

`adidas_pants.jpg`, `football_shorts.jpg`, `swimsuit.jpg`, `yoga_leggings.jpg` —
из открытого набора каталожных фото «Fashion Product Images» (Param Aggarwal,
лицензия MIT; копия на Hugging Face:
`benitomartin/fashion-product-images-small-900x1200`). Каталожные фото на белом
фоне лучше всего подходят для примерки по фото. Штаны, купальник и леггинсы
сняты на модели — приложение сообщает об этом серверу примерки
(`garment_type=model`, список в `PhotoTryOnService.modelPhotos`).

Фото спортсменов в «Зале славы» (`assets/images/exhibits/kz_*.jpg`) предоставлены
автором проекта.
