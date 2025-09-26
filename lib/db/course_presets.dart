// lib/db/course_presets.dart

import 'package:hetaumakeiba_v2/models/course_preset_model.dart';

final List<CoursePreset> coursePresets = [
  // ==========================================================================
  // SAPPORO RACECOURSE (01 札幌競馬場)
  // ==========================================================================
  CoursePreset(
      id: '01_shiba_1000',
      venueCode: '01',
      venueName: '札幌',
      distance: '芝1000',
      direction: '右回り',
      straightLength: 266,
      courseLayout: 'JRA全10場の中で最も高低差が少ない0.7mの平坦コース。2コーナー奥のポケットからスタートするワンターンレイアウト。',
      keyPoints: 'スタートから最初の3コーナーまでが短いため、内枠有利の傾向。スピードとダッシュ力が最重要で、逃げ・先行馬が圧倒的に有利。'
  ),
  CoursePreset(
      id: '01_shiba_1200',
      venueCode: '01',
      venueName: '札幌',
      distance: '芝1200',
      direction: '右回り',
      straightLength: 266,
      courseLayout: 'JRA全10場の中で最も高低差が少ない0.7mの平坦コース。2コーナー奥のポケットからスタートし、緩やかなコーナーを2つ回る。',
      keyPoints: 'スタートから最初のコーナーまでの距離が長く、枠順の有利不利は少ない。スピードの持続力が最も重要。先行力が基本だが、ハイペースになれば差しも決まる。'
  ),
  CoursePreset(
      id: '01_shiba_1500',
      venueCode: '01',
      venueName: '札幌',
      distance: '芝1500',
      direction: '右回り',
      straightLength: 266,
      courseLayout: 'JRA全10場の中で最も高低差が少ない0.7mの平坦コース。向こう正面からスタートし、コーナーを4つ回る。',
      keyPoints: 'スタート後すぐに3コーナーを迎えるため、外枠は距離ロスが生じやすい。先行力と、緩やかなコーナーをロスなく回る器用さが求められる。'
  ),
  CoursePreset(
      id: '01_shiba_1800',
      venueCode: '01',
      venueName: '札幌',
      distance: '芝1800',
      direction: '右回り',
      straightLength: 266,
      courseLayout: 'JRA全10場の中で最も高低差が少ない0.7mの平坦コース。スタンド前の直線からスタートし、コースを一周する。',
      keyPoints: 'スタートから最初の1コーナーまでが短いため、内枠が有利。ペースは落ち着きやすく、総合的な能力と騎手の立ち回りが重要になる。'
  ),
  CoursePreset(
      id: '01_shiba_2000',
      venueCode: '01',
      venueName: '札幌',
      distance: '芝2000',
      direction: '右回り',
      straightLength: 266,
      courseLayout: 'JRA全10場の中で最も高低差が少ない0.7mの平坦コース。4コーナー奥のポケットからスタートし、コースを一周する。G2札幌記念の舞台。',
      keyPoints: 'スタートから最初の1コーナーまで距離があり、枠順の有利不利は少ない。スタミナと長く良い脚を使える持続力が問われるコース。'
  ),
  CoursePreset(
      id: '01_shiba_2600',
      venueCode: '01',
      venueName: '札幌',
      distance: '芝2600',
      direction: '右回り',
      straightLength: 266,
      courseLayout: 'JRA全10場の中で最も高低差が少ない0.7mの平坦コース。向こう正面からスタートし、コースを一周半する。',
      keyPoints: 'コーナーを6回通過するため、スタミナはもちろん、ロスなく立ち回る器用さが非常に重要。仕掛けどころを含め騎手の腕が問われる。'
  ),
  CoursePreset(
      id: '01_dirt_1000',
      venueCode: '01',
      venueName: '札幌',
      distance: 'ダート1000',
      direction: '右回り',
      straightLength: 264,
      courseLayout: '高低差0.9mと平坦なダートコース。向こう正面からスタートし、3コーナーと4コーナーを回るワンターンレイアウト。',
      keyPoints: 'JRAのダート1000mで唯一芝スタートではないコース。純粋なダッシュ力が問われ、逃げ・先行馬が圧倒的に有利。'
  ),
  CoursePreset(
      id: '01_dirt_1700',
      venueCode: '01',
      venueName: '札幌',
      distance: 'ダート1700',
      direction: '右回り',
      straightLength: 264,
      courseLayout: '高低差0.9mと平坦なダートコース。スタンド前の直線からスタートし、コースを一周する札幌ダートのメインコース。',
      keyPoints: 'スタートから最初のコーナーまでが短く、先行争いが激しくなりやすい。コーナーが緩いため捲りも決まりやすく、スタミナも要求される。'
  ),
  CoursePreset(
      id: '01_dirt_2400',
      venueCode: '01',
      venueName: '札幌',
      distance: 'ダート2400',
      direction: '右回り',
      straightLength: 264,
      courseLayout: '高低差0.9mと平坦なダートコース。向こう正面からスタートし、コースを一周半する長丁場。',
      keyPoints: 'コーナーを6回通過するため、スタミナとロスのない立ち回りが求められる。ペースは落ち着きやすく、捲りが決まることもある。'
  ),

  // ==========================================================================
  // HAKODATE RACECOURSE (02 函館競馬場)
  // ==========================================================================
  CoursePreset(
      id: '02_shiba_1000',
      venueCode: '02',
      venueName: '函館',
      distance: '芝1000',
      direction: '右回り',
      straightLength: 262,
      courseLayout: '向正面からスタートし、3,4コーナーの上り坂を越えるワンターンコース。高低差は3.5mで、直線はJRA全場で最も短い。',
      keyPoints: 'スタート直後から上り坂のため、先行争いはスタミナを要する。直線が非常に短く、逃げ・先行馬が圧倒的に有利なコース。'
  ),
  CoursePreset(
      id: '02_shiba_1200',
      venueCode: '02',
      venueName: '函館',
      distance: '芝1200',
      direction: '右回り',
      straightLength: 262,
      courseLayout: '2コーナー奥のポケットからスタート。3,4コーナーの上り坂を越え、JRA全場で最も短い直線に向かう。高低差は3.5m。',
      keyPoints: '序盤の先行争いが丸々上り勾配で行われるタフなコース。直線が短いため、先行力と坂をこなすパワーが必須条件となる。'
  ),
  CoursePreset(
      id: '02_shiba_1700',
      venueCode: '02',
      venueName: '函館',
      distance: '芝1700',
      direction: '右回り',
      straightLength: 262,
      courseLayout: 'スタンド前直線からスタートしコースを一周する、JRA唯一の距離設定。高低差3.5mの起伏を越え、短い直線での勝負となる。',
      keyPoints: 'スタートから1コーナーまでが短くタイトなため、内枠が有利になりやすい。先行力と、起伏をこなすパワーが重要。'
  ),
  CoursePreset(
      id: '02_shiba_1800',
      venueCode: '02',
      venueName: '函館',
      distance: '芝1800',
      direction: '右回り',
      straightLength: 262,
      courseLayout: 'スタンド前直線からスタートしコースを一周する。高低差3.5mの起伏をフルに使い、直線はJRA全場で最も短い。',
      keyPoints: 'スタートから1コーナーまでが短く、先行争いが激しくなりやすい。短い直線と起伏をこなす総合力と立ち回りのうまさが問われる。'
  ),
  CoursePreset(
      id: '02_shiba_2000',
      venueCode: '02',
      venueName: '函館',
      distance: '芝2000',
      direction: '右回り',
      straightLength: 262,
      courseLayout: '4コーナー奥のポケットからスタートしコースを一周する。高低差3.5mの起伏があり、G3函館記念の舞台となる。',
      keyPoints: 'スタートから最初のコーナーまで距離があり、枠順の有利不利は少ない。スタミナと坂をこなすパワー、そして洋芝適性が重要。'
  ),
  CoursePreset(
      id: '02_shiba_2600',
      venueCode: '02',
      venueName: '函館',
      distance: '芝2600',
      direction: '右回り',
      straightLength: 262,
      courseLayout: '向正面からスタートし、コースを一周半する。上り坂を2回通過する、高低差3.5mのタフな長距離コース。',
      keyPoints: '上り坂を2回越えるため、スタミナとパワーが最も重要。ペースは落ち着きやすいが、騎手の仕掛けどころがレースを左右する。'
  ),
  CoursePreset(
      id: '02_dirt_1000',
      venueCode: '02',
      venueName: '函館',
      distance: 'ダート1000',
      direction: '右回り',
      straightLength: 260,
      courseLayout: '向正面からスタートするワンターンコース。芝コース同様、3,4コーナーにかけて上り坂が続く。高低差は3.5m。',
      keyPoints: 'スタートから上り坂を駆け上がるため、ダッシュ力とパワーが不可欠。直線も短く、逃げ・先行馬が圧倒的に有利。'
  ),
  CoursePreset(
      id: '02_dirt_1700',
      venueCode: '02',
      venueName: '函館',
      distance: 'ダート1700',
      direction: '右回り',
      straightLength: 260,
      courseLayout: 'スタンド前直線からスタートし、コースを一周するダートのメインコース。高低差3.5mの起伏があり、直線は短い。',
      keyPoints: '起伏のあるコースを一周するため、スタミナとパワーが要求される。直線が短いため先行力が重要だが、スパイラルカーブを利用した捲りにも注意が必要。'
  ),
  CoursePreset(
      id: '02_dirt_2400',
      venueCode: '02',
      venueName: '函館',
      distance: 'ダート2400',
      direction: '右回り',
      straightLength: 260,
      courseLayout: '向正面からスタートしコースを一周半する。上り坂を2回越える、高低差3.5mの非常にタフな長距離コース。',
      keyPoints: '2度の坂越えがあり、相当なスタミナが求められる。頭数が少なくなることが多く、騎手のペース判断と仕掛けどころが鍵となる。'
  ),

  // ==========================================================================
  // FUKUSHIMA RACECOURSE (03 福島競馬場)
  // ==========================================================================
  CoursePreset(
      id: '03_shiba_1000',
      venueCode: '03',
      venueName: '福島',
      distance: '芝1000',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '向正面からスタートするワンターンコース。1周1600mのコンパクトなコースで、向正面の上り坂とゴール前のアップダウンが待ち受ける。',
      keyPoints: '小回りかつ直線も短いため、先行力が絶対的に重要。スタート直後の上り坂をこなすパワーも求められる。'
  ),
  CoursePreset(
      id: '03_shiba_1200',
      venueCode: '03',
      venueName: '福島',
      distance: '芝1200',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '2コーナー奥のポケットからスタート。向正面の上り坂、スパイラルカーブを経て、アップダウンのある直線に向かう。高低差は1.9m。',
      keyPoints: '福島のメイン距離。先行力が基本だが、スパイラルカーブを利用して捲ることも可能。開催が進むと外差しが決まりやすくなる。'
  ),
  CoursePreset(
      id: '03_shiba_1700',
      venueCode: '03',
      venueName: '福島',
      distance: '芝1700',
      direction: '右回り',
      straightLength: 292,
      courseLayout: 'スタンド前からのスタートで、すぐに1コーナーを迎える。1周1600mのコースをフルに使い、2度のアップダウンを経験する。',
      keyPoints: 'スタートから最初のコーナーまでが短く、内枠が有利。小回り適性と起伏をこなすスタミナが要求されるトリッキーなコース。'
  ),
  CoursePreset(
      id: '03_shiba_1800',
      venueCode: '03',
      venueName: '福島',
      distance: '芝1800',
      direction: '右回り',
      straightLength: 292,
      courseLayout: 'スタンド前からのスタートでコースを一周する。コンパクトなコースに2度のアップダウンが組み込まれたレイアウト。',
      keyPoints: '1700m同様、スタートから1コーナーまでが短いため内枠有利。ペースが落ち着きやすく、騎手の位置取りや仕掛けどころが重要になる。'
  ),
  CoursePreset(
      id: '03_shiba_2000',
      venueCode: '03',
      venueName: '福島',
      distance: '芝2000',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '4コーナー奥のポケットからスタートし、コースを一周する。2度のアップダウンをこなす、福島の根幹コース。',
      keyPoints: 'スタートから1コーナーまで距離があり枠順の有利不利は少ない。スタミナとパワー、そして器用さが求められる。七夕賞の舞台。'
  ),
  CoursePreset(
      id: '03_shiba_2600',
      venueCode: '03',
      venueName: '福島',
      distance: '芝2600',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '向正面からスタートし、コースを一周半する長距離コース。何度もアップダウンを繰り返す非常にタフな設定。',
      keyPoints: 'スタミナが最も重要。小回りで何度もコーナーを回るため、ロスなく立ち回る器用さも必要。ペースは緩みやすい。'
  ),
  CoursePreset(
      id: '03_dirt_1000',
      venueCode: '03',
      venueName: '福島',
      distance: 'ダート1000',
      direction: '右回り',
      straightLength: 296,
      courseLayout: '向正面からスタートするワンターンコース。高低差2.1mの起伏があり、ゴール前に上り坂が待ち受ける。',
      keyPoints: '小回りダートの短距離戦で、スピードと先行力が全て。逃げ馬の勝率が非常に高いコース。'
  ),
  CoursePreset(
      id: '03_dirt_1150',
      venueCode: '03',
      venueName: '福島',
      distance: 'ダート1150',
      direction: '右回り',
      straightLength: 296,
      courseLayout: '2コーナー奥の芝ポケットからスタートする特殊なコース。内がダート、外が芝で、すぐに3コーナーを迎える。',
      keyPoints: '芝を長く走れる外枠が有利な傾向がある。スピードの持続力と、ダートへのコース替わりをスムーズにこなせるかが鍵。'
  ),
  CoursePreset(
      id: '03_dirt_1700',
      venueCode: '03',
      venueName: '福島',
      distance: 'ダート1700',
      direction: '右回り',
      straightLength: 296,
      courseLayout: 'スタンド前直線からスタートし、コースを一周する。高低差2.1mのアップダウンを2度繰り返すタフなコース。',
      keyPoints: 'ダートコースのメイン距離。逃げ・先行が有利だが、タフな流れになりやすく、差しが決まることもある。スタミナも要求される。'
  ),
  CoursePreset(
      id: '03_dirt_2400',
      venueCode: '03',
      venueName: '福島',
      distance: 'ダート2400',
      direction: '右回り',
      straightLength: 296,
      courseLayout: '向正面からスタートし、コースを一周半する長丁場。何度も起伏を越える非常にスタミナを要するコース。',
      keyPoints: 'スタミナの消耗が激しいタフなレース。ペースは落ち着きやすく、ロングスパートができる持続力のある馬に向く。'
  ),
  CoursePreset(
      id: '03_obstacle_2750',
      venueCode: '03',
      venueName: '福島',
      distance: '障害2750',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '襷コースと本馬場を使用する障害コース。バンケットを含む固定障害と置き障害を飛越する。Aコース使用時の距離。',
      keyPoints: '高低差2.7mのバンケットが名物。襷コースの小回り部分と本馬場のアップダウンをこなす総合力が問われる。'
  ),
  CoursePreset(
      id: '03_obstacle_2770',
      venueCode: '03',
      venueName: '福島',
      distance: '障害2770',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '襷コースと本馬場を使用する障害コース。バンケットを含む固定障害と置き障害を飛越する。Bコース使用時の距離。',
      keyPoints: '高低差2.7mのバンケットが名物。襷コースの小回り部分と本馬場のアップダウンをこなす総合力が問われる。'
  ),
  CoursePreset(
      id: '03_obstacle_2800',
      venueCode: '03',
      venueName: '福島',
      distance: '障害2800',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '襷コースと本馬場を使用する障害コース。バンケットを含む固定障害と置き障害を飛越する。Cコース使用時の距離。',
      keyPoints: '高低差2.7mのバンケットが名物。襷コースの小回り部分と本馬場のアップダウンをこなす総合力が問われる。'
  ),
  CoursePreset(
      id: '03_obstacle_3350',
      venueCode: '03',
      venueName: '福島',
      distance: '障害3350',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '襷コースと本馬場を組み合わせた長距離コース。名物のバンケット越えなど、数々の障害を飛越する。Aコース使用時の距離。',
      keyPoints: 'スタミナと飛越の巧さが不可欠。襷コースと本馬場を複数回行き来するため、コース取りとペース配分が鍵を握る。'
  ),
  CoursePreset(
      id: '03_obstacle_3380',
      venueCode: '03',
      venueName: '福島',
      distance: '障害3380',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '襷コースと本馬場を組み合わせた長距離コース。名物のバンケット越えなど、数々の障害を飛越する。Bコース使用時の距離。',
      keyPoints: 'スタミナと飛越の巧さが不可欠。襷コースと本馬場を複数回行き来するため、コース取りとペース配分が鍵を握る。'
  ),
  CoursePreset(
      id: '03_obstacle_3410',
      venueCode: '03',
      venueName: '福島',
      distance: '障害3410',
      direction: '右回り',
      straightLength: 292,
      courseLayout: '襷コースと本馬場を組み合わせた長距離コース。名物のバンケット越えなど、数々の障害を飛越する。Cコース使用時の距離。',
      keyPoints: 'スタミナと飛越の巧さが不可欠。襷コースと本馬場を複数回行き来するため、コース取りとペース配分が鍵を握る。'
  ),

  // ==========================================================================
  // NIIGATA RACECOURSE (04 新潟競馬場)
  // ==========================================================================
  CoursePreset(
      id: '04_shiba_straight_1000',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝1000(直線)',
      direction: '直線',
      straightLength: 1000,
      courseLayout: 'JRA唯一の直線のみで構成される名物コース。スタートからゴールまで1000mの直線を走る。',
      keyPoints: '外枠が圧倒的に有利とされる独特なコース。スピードとパワーが重要で、「千直巧者」と呼ばれるスペシャリストが存在する。'
  ),
  CoursePreset(
      id: '04_shiba_uchi_1200',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝1200(内)',
      direction: '左回り',
      straightLength: 359,
      courseLayout: '向正面からのワンターン。高低差0.8mと平坦で、直線も短い内回りを使用する。',
      keyPoints: 'コーナーがタイトなため小回り適性が求められ、先行力が重要。器用に立ち回れる馬や騎手が有利。'
  ),
  CoursePreset(
      id: '04_shiba_uchi_1400',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝1400(内)',
      direction: '左回り',
      straightLength: 359,
      courseLayout: '2コーナーのポケットからスタート。高低差0.8mと平坦な内回りコースを使用し、最後の直線は358.7m。',
      keyPoints: 'スタートから最初のコーナーまで距離があり枠の有利不利は少ない。先行力と器用さが求められる。'
  ),
  CoursePreset(
      id: '04_shiba_soto_1400',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝1400(外)',
      direction: '左回り',
      straightLength: 659,
      courseLayout: '向正面からのワンターン。日本最長の658.7mの直線を誇る外回りコースを使用する。',
      keyPoints: '直線が非常に長いため、差し・追込馬にもチャンスがある。瞬発力勝負になりやすい。'
  ),
  CoursePreset(
      id: '04_shiba_soto_1600',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝1600(外)',
      direction: '左回り',
      straightLength: 659,
      courseLayout: '向正面からのワンターン。日本最長の658.7mの直線を誇る外回りコースを使用。G3関屋記念の舞台。',
      keyPoints: 'ワンターンで紛れが少なく、実力が反映されやすい。長い直線を活かせる瞬発力と持続力が重要。'
  ),
  CoursePreset(
      id: '04_shiba_soto_1800',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝1800(外)',
      direction: '左回り',
      straightLength: 659,
      courseLayout: 'スタンド前からスタートし、外回りコースを使用する。日本最長の658.7mの直線が待ち受ける。',
      keyPoints: 'スタートから最初のコーナーまで距離があり、枠の有利不利は少ない。長い直線での瞬発力勝負になりやすい。'
  ),
  CoursePreset(
      id: '04_shiba_uchi_2000',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝2000(内)',
      direction: '左回り',
      straightLength: 359,
      courseLayout: 'スタンド前からスタートし、内回りコースを一周する。直線が短く、コーナーを4つ回る小回りコース。',
      keyPoints: 'スタートから1コーナーまでが短いため内枠有利。器用さと立ち回りのうまさが重要。'
  ),
  CoursePreset(
      id: '04_shiba_soto_2000',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝2000(外)',
      direction: '左回り',
      straightLength: 659,
      courseLayout: '向正面からスタートし、外回りコースを使用。3コーナー手前まで上り、日本最長の直線で勝負が決まる。',
      keyPoints: 'コーナーは2回のみ。スタミナと長い直線を走り切る末脚の持続力が求められる。'
  ),
  CoursePreset(
      id: '04_shiba_uchi_2200',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝2200(内)',
      direction: '左回り',
      straightLength: 359,
      courseLayout: '向正面からのスタートで内回りコースを一周する。直線が短く、4つのコーナーを回るレイアウト。',
      keyPoints: 'スタミナと小回り適性の両方が求められる。騎手のペース判断と位置取りが鍵を握る。'
  ),
  CoursePreset(
      id: '04_shiba_uchi_2400',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝2400(内)',
      direction: '左回り',
      straightLength: 359,
      courseLayout: '向正面からスタートし、内回りコースを一周半する。コーナーを6回通過するトリッキーなコース。',
      keyPoints: 'スタミナはもちろん、何度もコーナーを回る器用さが非常に重要。騎手の腕が試される。'
  ),
  CoursePreset(
      id: '04_shiba_soto_3000',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝3000(外)',
      direction: '左回り',
      straightLength: 659,
      courseLayout: '外回りコースを約1周半する長距離戦。日本一長い直線と大きなコーナーが特徴。',
      keyPoints: 'スタミナが絶対的に重要。コースが広いため紛れは少ないが、長い直線での末脚比べになるため、持続力が問われる。'
  ),
  CoursePreset(
      id: '04_shiba_soto_3200',
      venueCode: '04',
      venueName: '新潟',
      distance: '芝3200(外)',
      direction: '左回り',
      straightLength: 659,
      courseLayout: '外回りコースを約1周半するステイヤーコース。日本一長い直線と大きなコーナーが特徴。',
      keyPoints: 'スタミナが絶対的に重要。コースが広いため紛れは少ないが、長い直線での末脚比べになるため、持続力が問われる。'
  ),
  CoursePreset(
      id: '04_dirt_1000',
      venueCode: '04',
      venueName: '新潟',
      distance: 'ダート1000',
      direction: '左回り',
      straightLength: 354,
      courseLayout: '向正面からのワンターン。高低差0.6mとほぼ平坦なコース。',
      keyPoints: '短距離戦のため、スタートダッシュと先行力が絶対的に有利。'
  ),
  CoursePreset(
      id: '04_dirt_1200',
      venueCode: '04',
      venueName: '新潟',
      distance: 'ダート1200',
      direction: '左回り',
      straightLength: 354,
      courseLayout: '芝スタートのワンターンコース。高低差0.6mとほぼ平坦で、最後の直線は353.9m。',
      keyPoints: '外枠の方が芝を長く走れるため有利な傾向。スピードの持続力が問われる。'
  ),
  CoursePreset(
      id: '04_dirt_1700',
      venueCode: '04',
      venueName: '新潟',
      distance: 'ダート1700',
      direction: '左回り',
      straightLength: 354,
      courseLayout: 'スタンド前からスタートし、コースを一周する。高低差0.6mの平坦なコース。',
      keyPoints: 'スタートから1コーナーまでが短く、先行争いが激しくなりやすい。平坦なためスピードの持続力が重要。'
  ),
  CoursePreset(
      id: '04_dirt_1800',
      venueCode: '04',
      venueName: '新潟',
      distance: 'ダート1800',
      direction: '左回り',
      straightLength: 354,
      courseLayout: 'スタンド前からスタートし、コースを一周する。高低差0.6mの平坦なコース。',
      keyPoints: 'ダートの主要距離。平坦で紛れが少なく、先行力とスピードが重要になる。'
  ),
  CoursePreset(
      id: '04_dirt_2500',
      venueCode: '04',
      venueName: '新潟',
      distance: 'ダート2500',
      direction: '左回り',
      straightLength: 354,
      courseLayout: '向正面からスタートし、コースを一周半する長丁場。高低差0.6mと平坦なコース。',
      keyPoints: 'コーナーを6回通過するため、スタミナと器用さが求められる。ペースが落ち着きやすい。'
  ),
  CoursePreset(
      id: '04_obstacle_2850',
      venueCode: '04',
      venueName: '新潟',
      distance: '障害2850',
      direction: '左回り',
      straightLength: 359,
      courseLayout: '外回りコースからスタートし、内回りコースへコース変更を行う独特なレイアウト。固定障害はなく、置き障害のみで争われる。Aコース使用時。',
      keyPoints: '広大な外回りからタイトな内回りへの対応力が鍵。飛越の巧さに加え、コース取りの判断も重要になる。'
  ),
  CoursePreset(
      id: '04_obstacle_2890',
      venueCode: '04',
      venueName: '新潟',
      distance: '障害2890',
      direction: '左回り',
      straightLength: 359,
      courseLayout: '外回りコースからスタートし、内回りコースへコース変更を行う独特なレイアウト。固定障害はなく、置き障害のみで争われる。Bコース使用時。',
      keyPoints: '広大な外回りからタイトな内回りへの対応力が鍵。飛越の巧さに加え、コース取りの判断も重要になる。'
  ),
  CoursePreset(
      id: '04_obstacle_3250',
      venueCode: '04',
      venueName: '新潟',
      distance: '障害3250',
      direction: '左回り',
      straightLength: 359,
      courseLayout: '外回りコースと内回りコースを組み合わせた長距離コース。固定障害はなく、置き障害のみで争われる。Aコース使用時。',
      keyPoints: 'スタミナが最も重要視される。外回りと内回りを複数回行き来するため、騎手のペース配分とコース取りが勝敗を分ける。'
  ),
  CoursePreset(
      id: '04_obstacle_3290',
      venueCode: '04',
      venueName: '新潟',
      distance: '障害3290',
      direction: '左回り',
      straightLength: 359,
      courseLayout: '外回りコースと内回りコースを組み合わせた長距離コース。固定障害はなく、置き障害のみで争われる。Bコース使用時。',
      keyPoints: 'スタミナが最も重要視される。外回りと内回りを複数回行き来するため、騎手のペース配分とコース取りが勝敗を分ける。'
  ),

  // ==========================================================================
  // TOKYO RACECOURSE (05 東京競馬場)
  // ==========================================================================
  CoursePreset(
      id: '05_shiba_1400',
      venueCode: '05',
      venueName: '東京',
      distance: '芝1400',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '向正面からのワンターン。高低差2.7mのタフなコースで、長い直線に高低差2mの上り坂が待ち受ける。',
      keyPoints: '枠順の有利不利は少ない。スタミナと長い直線を走り切る末脚のスピードと持続力が問われる。京王杯SCの舞台。'
  ),
  CoursePreset(
      id: '05_shiba_1600',
      venueCode: '05',
      venueName: '東京',
      distance: '芝1600',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '向正面からのワンターン。長い下り坂を経て、広くて長い直線での勝負となる。安田記念、NHKマイルC、ヴィクトリアマイルの舞台。',
      keyPoints: 'マイル王決定戦の舞台。紛れが少なく、スピードと瞬発力が高いレベルで要求される、実力が反映されやすいコース。'
  ),
  CoursePreset(
      id: '05_shiba_1800',
      venueCode: '05',
      venueName: '東京',
      distance: '芝1800',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '2コーナー手前のポケットからスタート。変則的なワンターンで、長い直線とゴール前の坂が待ち受ける。毎日王冠の舞台。',
      keyPoints: 'スタートから最初のコーナーまでが長く、枠順の有利不利は少ない。スピードとスタミナのバランスが問われる。'
  ),
  CoursePreset(
      id: '05_shiba_2000',
      venueCode: '05',
      venueName: '東京',
      distance: '芝2000',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '1コーナー手前のポケットからスタートし、コースを一周する。天皇賞(秋)の舞台。',
      keyPoints: 'スタート直後にコーナーがあるため、内枠がやや有利。長い直線での瞬発力に加え、ペース配分や位置取りも重要になる。'
  ),
  CoursePreset(
      id: '05_shiba_2300',
      venueCode: '05',
      venueName: '東京',
      distance: '芝2300',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '向正面からスタートし、2コーナーから1コーナーへと向かう変則的なコース。長い直線とゴール前の坂を越える。',
      keyPoints: 'スタートからコーナーまでが遠く、枠順の有利不利は少ない。スタミナと長い直線で脚を使える持続力が問われる。'
  ),
  CoursePreset(
      id: '05_shiba_2400',
      venueCode: '05',
      venueName: '東京',
      distance: '芝2400',
      direction: '左回り',
      straightLength: 526,
      courseLayout: 'スタンド前からスタートし、コースを一周する。「ダービーコース」として知られ、日本の競馬を象徴するレイアウト。',
      keyPoints: '日本ダービー、ジャパンカップ、オークスの舞台。能力、スタミナ、スピード、そして運の全てが試される最高のチャンピオン決定コース。'
  ),
  CoursePreset(
      id: '05_shiba_2500',
      venueCode: '05',
      venueName: '東京',
      distance: '芝2500',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '2400mより100m奥のスタンド前からスタート。アルゼンチン共和国杯、目黒記念の舞台。',
      keyPoints: '2400m同様、総合力が問われる。長丁場でありながら、最後の直線勝負に対応できる瞬発力も必要。'
  ),
  CoursePreset(
      id: '05_shiba_2600',
      venueCode: '05',
      venueName: '東京',
      distance: '芝2600',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '2500mよりさらに奥からスタート。スタンド前の直線から1周する長距離コース。',
      keyPoints: '長距離戦であり、スタミナが必須。広いコースで紛れが少ないため、馬の実力が反映されやすい。'
  ),
  CoursePreset(
      id: '05_shiba_3400',
      venueCode: '05',
      venueName: '東京',
      distance: '芝3400',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '向正面からスタートし、コースを約一周半する長距離コース。ダイヤモンドSの舞台。',
      keyPoints: '2度の坂越えと長い直線があり、スタミナが最も重要。騎手のペース配分と馬の折り合いが勝敗を分ける。'
  ),
  CoursePreset(
      id: '05_dirt_1200',
      venueCode: '05',
      venueName: '東京',
      distance: 'ダート1200',
      direction: '左回り',
      straightLength: 502,
      courseLayout: '向正面からのワンターン。最後の直線は501.6mと非常に長く、ゴール前に急坂が待ち受ける。',
      keyPoints: '直線が長いため、ダート短距離としては差しが決まりやすい。坂をこなすパワーも必須。'
  ),
  CoursePreset(
      id: '05_dirt_1300',
      venueCode: '05',
      venueName: '東京',
      distance: 'ダート1300',
      direction: '左回り',
      straightLength: 502,
      courseLayout: '向正面の芝地点からスタート。最後の直線は501.6mと長く、ゴール前に急坂が待ち受ける。',
      keyPoints: '芝スタートのため外枠が有利。直線が長いため、ハイペースになれば差し・追い込みも届く。'
  ),
  CoursePreset(
      id: '05_dirt_1400',
      venueCode: '05',
      venueName: '東京',
      distance: 'ダート1400',
      direction: '左回り',
      straightLength: 502,
      courseLayout: '2コーナー奥の芝地点からスタート。日本一長いダート直線(501.6m)と、高低差2.4mのゴール前の急坂が特徴。',
      keyPoints: '芝スタートのため、外枠のほうが芝を長く走れ有利。スピードと坂をこなすパワーが求められる。'
  ),
  CoursePreset(
      id: '05_dirt_1600',
      venueCode: '05',
      venueName: '東京',
      distance: 'ダート1600',
      direction: '左回り',
      straightLength: 502,
      courseLayout: '向正面の芝部分からスタートするワンターンコース。G1フェブラリーSの舞台。',
      keyPoints: 'G1コース。芝スタートのため外枠有利。広いコースで紛れが少なく、ダートマイル王を決めるにふさわしい実力勝負のコース。'
  ),
  CoursePreset(
      id: '05_dirt_2100',
      venueCode: '05',
      venueName: '東京',
      distance: 'ダート2100',
      direction: '左回り',
      straightLength: 502,
      courseLayout: 'スタンド前からスタートし、コースを一周する。日本一長いダート直線とゴール前の急坂を越えるタフなコース。',
      keyPoints: 'スタミナとパワーが非常に高いレベルで要求される。差し・追い込みも決まりやすい。'
  ),
  CoursePreset(
      id: '05_dirt_2400',
      venueCode: '05',
      venueName: '東京',
      distance: 'ダート2400',
      direction: '左回り',
      straightLength: 502,
      courseLayout: 'スタンド前からスタートし、コースを一周する長距離戦。2度の坂越えがある過酷なコース。',
      keyPoints: 'ダートの長距離戦。スタミナが最も重要で、馬の底力が試される。'
  ),
  CoursePreset(
      id: '05_obstacle_dirt_3000',
      venueCode: '05',
      venueName: '東京',
      distance: '障害3000(ダート)',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '本馬場のダートコースからスタートし、障害専用コースへ進入。水ごうやいけ垣など多彩な固定障害を飛越する。',
      keyPoints: 'ダートからのスタートが序盤の位置取りに影響する。スタミナと障害への対応力が試される。'
  ),
  CoursePreset(
      id: '05_obstacle_dirt_3100',
      venueCode: '05',
      venueName: '東京',
      distance: '障害3100(ダート)',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '本馬場のダートコースからスタートし、障害専用コースへ進入。多彩な固定障害とタフなコースレイアウトが特徴。',
      keyPoints: 'ダートからのスタートが序盤の位置取りに影響する。スタミナと障害への対応力が試される。'
  ),
  CoursePreset(
      id: '05_obstacle_shiba_3110',
      venueCode: '05',
      venueName: '東京',
      distance: '障害3110(芝)',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '本馬場の芝コースからスタートし、内側の障害専用コースへ進入。水ごうやいけ垣など多彩な固定障害を飛越する。',
      keyPoints: 'G2東京ハイジャンプの舞台。難易度の高い障害が設置され、真のジャンパーの実力が問われる。スタミナと高度な飛越技術が必要。'
  ),
  CoursePreset(
      id: '05_obstacle_shiba_3300',
      venueCode: '05',
      venueName: '東京',
      distance: '障害3300(芝)',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '本馬場の芝コースからスタートし、障害専用コースを周回する。水ごうや大いけ垣・大竹柵(重賞時)など難関障害が待ち受ける。',
      keyPoints: 'スタミナと障害への絶対的な能力が求められるコース。特に重賞ではより難易度の高い障害が設置される。'
  ),
  CoursePreset(
      id: '05_obstacle_dirt_3300',
      venueCode: '05',
      venueName: '東京',
      distance: '障害3300(ダート)',
      direction: '左回り',
      straightLength: 526,
      courseLayout: '本馬場のダートコースからスタートし、障害専用コースを周回する長距離戦。水ごうなどの固定障害を飛越する。',
      keyPoints: 'ダートスタートの長距離障害戦。スタミナと飛越の巧さが問われる。'
  ),

  // ==========================================================================
  // NAKAYAMA RACECOURSE (06 中山競馬場)
  // ==========================================================================
  CoursePreset(
      id: '06_shiba_soto_1200',
      venueCode: '06',
      venueName: '中山',
      distance: '芝1200(外)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '外回りコースを使用するワンターン。2コーナーから4コーナーまで下り坂が続き、ゴール前にJRAで最も勾配が急な坂が待ち受ける。',
      keyPoints: 'G1スプリンターズSの舞台。スタート後の位置取りと、最後の急坂をものともしないパワーが重要。ハイペースになりやすい。'
  ),
  CoursePreset(
      id: '06_shiba_soto_1600',
      venueCode: '06',
      venueName: '中山',
      distance: '芝1600(外)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '外回りコースを使用するワンターン。スタートから最初のコーナーまで距離があり、最後の直線には名物の急坂が待ち構える。',
      keyPoints: '枠順の有利不利は少ない。コーナー2回のレイアウトだが、最後の坂が厳しく、マイル以上のスタミナも要求される。'
  ),
  CoursePreset(
      id: '06_shiba_uchi_1800',
      venueCode: '06',
      venueName: '中山',
      distance: '芝1800(内)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '内回りコースを一周する。スタート直後とゴール前に2度の急坂越えがあり、コーナーもタイトなタフなコース。',
      keyPoints: '器用さとパワー、スタミナが要求される。4つのタイトなコーナーを回るため、先行できる馬が有利になりやすい。'
  ),
  CoursePreset(
      id: '06_shiba_uchi_2000',
      venueCode: '06',
      venueName: '中山',
      distance: '芝2000(内)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '内回りコースを一周する。スタート地点が急坂の頂上付近で、ゴール前の急坂と合わせて2回坂を上る。G1皐月賞の舞台。',
      keyPoints: 'クラシック第一弾の舞台。小回りで紛れが多く、ペースが速くなりやすい。総合力と幾度も坂をこなすタフさが試される。'
  ),
  CoursePreset(
      id: '06_shiba_soto_2200',
      venueCode: '06',
      venueName: '中山',
      distance: '芝2200(外)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '外回りコースを一周する。内回り2000mよりコーナーが緩やかで、スタミナがより問われるレイアウト。',
      keyPoints: 'スタミナと長く良い脚を使える持続力が重要。ペースが落ち着きやすく、騎手の仕掛けどころが勝敗を分けることが多い。'
  ),
  CoursePreset(
      id: '06_shiba_uchi_2500',
      venueCode: '06',
      venueName: '中山',
      distance: '芝2500(内)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '外回りコースの3コーナー手前からスタートし、内回りコースを一周する特殊なレイアウト。コーナーを6回通過し、2度の急坂越えがある。',
      keyPoints: 'グランプリ有馬記念の舞台。スタミナ、パワー、器用さ、そして勝負運の全てが要求される年末の大一番にふさわしいコース。'
  ),
  CoursePreset(
      id: '06_shiba_soto_2600',
      venueCode: '06',
      venueName: '中山',
      distance: '芝2600(外)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '外回りコースを約1周半する長距離コース。2度の急坂越えと、6つのコーナーを回るタフなコース。',
      keyPoints: 'スタミナと持久力が求められる。騎手のペース配分と馬の折り合いが重要。'
  ),
  CoursePreset(
      id: '06_shiba_w_3200',
      venueCode: '06',
      venueName: '中山',
      distance: '芝3200(外・内)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '外回りコースをスタートし、1周後に内回りコースへ合流する特殊な長距離コース。',
      keyPoints: '外回りのゆったりした流れから、内回りのタイトな流れに変わる対応力が求められる。スタミナと騎手の腕が試される。'
  ),
  CoursePreset(
      id: '06_shiba_uchi_3600',
      venueCode: '06',
      venueName: '中山',
      distance: '芝3600(内)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '内回りコースを2周する長距離戦。合計4回急坂を上り、コーナーは8回通過する。G2ステイヤーズSの舞台。',
      keyPoints: 'JRA平地最長距離の重賞が行われる。スタミナが全てと言っても過言ではなく、騎手のペース配分と馬の折り合いが極めて重要。'
  ),
  CoursePreset(
      id: '06_shiba_soto_4000',
      venueCode: '06',
      venueName: '中山',
      distance: '芝4000(外)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '外回りコースを2周以上する、平地競走では非常に珍しい長距離コース。',
      keyPoints: '究極のスタミナ比べ。騎手のペース判断が全てを分けると言っても過言ではない。'
  ),
  CoursePreset(
      id: '06_dirt_1000',
      venueCode: '06',
      venueName: '中山',
      distance: 'ダート1000',
      direction: '右回り',
      straightLength: 308,
      courseLayout: '向正面からのワンターン。ゴール前に高低差約2.2mの急坂が待ち構える。',
      keyPoints: 'スタートからゴールまでほぼ下り坂だが、最後の急坂で形勢が逆転する。スピードと急坂をこなすパワーが必要。'
  ),
  CoursePreset(
      id: '06_dirt_1200',
      venueCode: '06',
      venueName: '中山',
      distance: 'ダート1200',
      direction: '右回り',
      straightLength: 308,
      courseLayout: '向正面の芝地点からスタートするワンターン。ゴール前の急坂が最大の難関。',
      keyPoints: '芝スタートのため外枠有利。前半は下り坂でスピードに乗りやすいが、最後の急坂で失速する馬も多く、パワーが必須。'
  ),
  CoursePreset(
      id: '06_dirt_1700',
      venueCode: '06',
      venueName: '中山',
      distance: 'ダート1700',
      direction: '右回り',
      straightLength: 308,
      courseLayout: 'スタンド前からスタートし、コースを一周する。2度の急坂越えがあるタフなコース。',
      keyPoints: '1800mよりもスタートから1コーナーまでが短く、先行争いが激しくなりやすい。パワーとスタミナが重要。'
  ),
  CoursePreset(
      id: '06_dirt_1800',
      venueCode: '06',
      venueName: '中山',
      distance: 'ダート1800',
      direction: '右回り',
      straightLength: 308,
      courseLayout: 'スタンド前からスタートし、コースを一周する。スタート直後とゴール前の2度、急坂を上るタフなコース。',
      keyPoints: 'ダートの主要距離でG1チャンピオンズCの前哨戦も行われる。パワーとスタミナが非常に重要。先行馬が有利だが、ハイペースになれば差しも決まる。'
  ),
  CoursePreset(
      id: '06_dirt_2400',
      venueCode: '06',
      venueName: '中山',
      distance: 'ダート2400',
      direction: '右回り',
      straightLength: 308,
      courseLayout: 'スタンド前からスタートし、コースを一周半する。4回急坂を通過する非常に過酷なレイアウト。',
      keyPoints: 'JRAのダート最長距離級のレース。圧倒的なスタミナとパワーがなければ走りきれない。'
  ),
  CoursePreset(
      id: '06_dirt_2500',
      venueCode: '06',
      venueName: '中山',
      distance: 'ダート2500',
      direction: '右回り',
      straightLength: 308,
      courseLayout: 'スタンド前からスタートし、2400mより100m奥からスタートする長距離戦。4度の坂越えがある。',
      keyPoints: '究極のスタミナ比べ。馬の底力が試されるコース。'
  ),
  CoursePreset(
      id: '06_obstacle_daishogai_4250',
      venueCode: '06',
      venueName: '中山',
      distance: '障害4250(大障害)',
      direction: '右回り',
      straightLength: 310,
      courseLayout: '年に2回しか使われない大障害専用の襷コースを使用。大竹柵や大いけ垣、谷を上り下りする坂路障害など、JRAで最も難易度の高い障害が待ち受ける。',
      keyPoints: 'J-G1中山グランドジャンプ、中山大障害の舞台。完走すること自体が名誉とされる。馬と騎手の勇気、技術、スタミナの全てが試される。'
  ),

  // ==========================================================================
  // CHUKYO RACECOURSE (07 中京競馬場)
  // ==========================================================================
  CoursePreset(
      id: '07_shiba_1200',
      venueCode: '07',
      venueName: '中京',
      distance: '芝1200',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '向正面からのワンターン。スタートから緩やかに上り、3-4コーナーのスパイラルカーブを下って、直線入口の急坂を駆け上がる。',
      keyPoints: 'G1高松宮記念の舞台。タフなレイアウトで、単純なスピードだけでは押し切れない。坂をこなすパワーとスタミナが要求される。'
  ),
  CoursePreset(
      id: '07_shiba_1300',
      venueCode: '07',
      venueName: '中京',
      distance: '芝1300',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '向正面からのワンターン。1200mより100mスタートが下がり、よりスタミナが問われる。最後の直線は長く、急坂が待ち受ける。',
      keyPoints: '珍しい距離設定。長い直線と急坂があるため、スピードだけでなく、坂を駆け上がるパワーと持久力が求められる。'
  ),
  CoursePreset(
      id: '07_shiba_1400',
      venueCode: '07',
      venueName: '中京',
      distance: '芝1400',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '2コーナー奥のポケットからスタート。ワンターンだが距離が長く、最後の直線勝負になりやすい。',
      keyPoints: '枠順の有利不利は少ない。長い直線と急坂があるため、差し・追い込みが決まりやすいコース。'
  ),
  CoursePreset(
      id: '07_shiba_1600',
      venueCode: '07',
      venueName: '中京',
      distance: '芝1600',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '2コーナー奥のポケットからスタート。向正面の坂を上り下りし、最後の直線412.5mで急坂を越える。',
      keyPoints: 'G3中京記念の舞台。紛れが少なく実力勝負になりやすい。末脚の持続力が問われる。'
  ),
  CoursePreset(
      id: '07_shiba_2000',
      venueCode: '07',
      venueName: '中京',
      distance: '芝2000',
      direction: '左回り',
      straightLength: 413,
      courseLayout: 'スタンド前からスタートし、コースを一周する。スタート直後とゴール前の2度、急坂を上ることになるタフなレイアウト。',
      keyPoints: 'スタートから最初のコーナーまで距離があり、枠順の有利不利は少ない。スタミナとパワー、総合力が求められる。'
  ),
  CoursePreset(
      id: '07_shiba_2200',
      venueCode: '07',
      venueName: '中京',
      distance: '芝2200',
      direction: '左回り',
      straightLength: 413,
      courseLayout: 'スタンド前からスタートし、コースを一周する。2000mよりスタート位置が後ろになる分、よりスタミナが問われる。',
      keyPoints: 'G2神戸新聞杯の舞台。長めの距離に2度の坂越えがあり、スタミナと底力が試される。'
  ),
  CoursePreset(
      id: '07_shiba_3000',
      venueCode: '07',
      venueName: '中京',
      distance: '芝3000',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '向正面からスタートし、コースを一周半する。急坂を2度上る非常にタフな長距離コース。',
      keyPoints: 'JRA平地のG1を除く最長距離レースのひとつ、万葉Sが行われる。圧倒的なスタミナと騎手のペース配分が不可欠。'
  ),
  CoursePreset(
      id: '07_dirt_1200',
      venueCode: '07',
      venueName: '中京',
      distance: 'ダート1200',
      direction: '左回り',
      straightLength: 411,
      courseLayout: '向正面からのワンターンコース。最後の直線は410.7mと長く、入口には急坂が待ち構える。',
      keyPoints: '直線が長く急坂もあるため、ダート短距離としては差しが決まりやすい。先行力に加え、坂をこなすパワーも必要。'
  ),
  CoursePreset(
      id: '07_dirt_1400',
      venueCode: '07',
      venueName: '中京',
      distance: 'ダート1400',
      direction: '左回り',
      straightLength: 411,
      courseLayout: '向正面の芝地点からスタートするワンターン。最後の直線は410.7mと長く、入口には急坂が待ち構える。',
      keyPoints: '芝スタートのため外枠が有利な傾向。長い直線と急坂により、差し・追い込みが決まりやすいダートでは珍しいコース。'
  ),
  CoursePreset(
      id: '07_dirt_1800',
      venueCode: '07',
      venueName: '中京',
      distance: 'ダート1800',
      direction: '左回り',
      straightLength: 411,
      courseLayout: 'スタンド前からスタートし、コースを一周する。スタート直後とゴール前の2度、急坂を上る。',
      keyPoints: 'G1チャンピオンズカップの舞台。日本一タフなダート1800mとも言われ、パワーとスタミナが必須。実力がストレートに反映される。'
  ),
  CoursePreset(
      id: '07_dirt_1900',
      venueCode: '07',
      venueName: '中京',
      distance: 'ダート1900',
      direction: '左回り',
      straightLength: 411,
      courseLayout: 'スタンド前からスタートする。1800mより100mスタート位置が下がる分、1コーナーまでの距離が長くなる。',
      keyPoints: '1800mよりは先行争いが緩やかになりやすいが、2度の坂越えがあるタフなコースであることに変わりはない。'
  ),
  CoursePreset(
      id: '07_dirt_2500',
      venueCode: '07',
      venueName: '中京',
      distance: 'ダート2500',
      direction: '左回り',
      straightLength: 411,
      courseLayout: '向正面からスタートし、コースを一周半する長丁場。急坂を2度上る過酷なコース。',
      keyPoints: 'ダートの長距離戦。スタミナとパワーはもちろん、6つのコーナーをこなす器用さも求められる。'
  ),
  CoursePreset(
      id: '07_obstacle_3000',
      venueCode: '07',
      venueName: '中京',
      distance: '障害3000',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '専用コースはなく、本馬場の芝コース上に置き障害を設置して行われる。タフな芝コースのアップダウンがそのまま活かされる。',
      keyPoints: '固定障害やバンケットがないため、障害コースとしてはスピードと平地力が要求される。スタミナも必須。'
  ),
  CoursePreset(
      id: '07_obstacle_3300',
      venueCode: '07',
      venueName: '中京',
      distance: '障害3300',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '本馬場の芝コース上に置き障害を設置。Aコース使用時の距離。2度の急坂越えを含むタフなレイアウト。',
      keyPoints: '平地力とスタミナが問われる。置き障害のため、飛越の巧さよりもスピード能力が活きやすい。'
  ),
  CoursePreset(
      id: '07_obstacle_3330',
      venueCode: '07',
      venueName: '中京',
      distance: '障害3330',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '本馬場の芝コース上に置き障害を設置。Bコース使用時の距離。2度の急坂越えを含むタフなレイアウト。',
      keyPoints: '平地力とスタミナが問われる。置き障害のため、飛越の巧さよりもスピード能力が活きやすい。'
  ),
  CoursePreset(
      id: '07_obstacle_3600',
      venueCode: '07',
      venueName: '中京',
      distance: '障害3600',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '本馬場の芝コース上に置き障害を設置する長距離戦。Aコース使用時の距離。急坂を複数回上り下りする。',
      keyPoints: '長丁場のため、スタミナの消耗が激しい。騎手のペース配分と馬の折り合いが重要になる。'
  ),
  CoursePreset(
      id: '07_obstacle_3900',
      venueCode: '07',
      venueName: '中京',
      distance: '障害3900',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '本馬場の芝コース上に置き障害を設置する長距離戦。Aコース使用時の距離。スタミナ消耗の激しいコース。',
      keyPoints: '平地力とスタミナが非常に高いレベルで要求される。完走するためには相当な底力が必要。'
  ),
  CoursePreset(
      id: '07_obstacle_3940',
      venueCode: '07',
      venueName: '中京',
      distance: '障害3940',
      direction: '左回り',
      straightLength: 413,
      courseLayout: '本馬場の芝コース上に置き障害を設置する長距離戦。Bコース使用時の距離。スタミナ消耗の激しいコース。',
      keyPoints: '平地力とスタミナが非常に高いレベルで要求される。完走するためには相当な底力が必要。'
  ),


  // ==========================================================================
  // KYOTO RACECOURSE (08 京都競馬場)
  // ==========================================================================

  // 芝コース (Turf Courses)
  CoursePreset(
      id: '08_shiba_uchi_1100',
      venueCode: '08',
      venueName: '京都',
      distance: '芝1100(内)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: '内回りコースを使用する短距離戦。向正面からスタートし、すぐに3コーナーの坂を上り、下りながら最後の直線に向かう。',
      keyPoints: 'JRAでは珍しい距離設定。直線が短く平坦なため、スタートダッシュと先行力が非常に重要。'
  ),
  CoursePreset(
      id: '08_shiba_uchi_1200',
      venueCode: '08',
      venueName: '京都',
      distance: '芝1200(内)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: '内回りコースを使用。向正面からスタートし、すぐに3コーナーの坂を上り、下りながら最後の直線に向かう。',
      keyPoints: '京阪杯(G3)の舞台。スタートから坂の頂上までが短く、位置取りが重要。直線が短く平坦なため、先行力と器用さが求められる。'
  ),
  CoursePreset(
      id: '08_shiba_uchi_1400',
      venueCode: '08',
      venueName: '京都',
      distance: '芝1400(内)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: '2コーナーからスタートし、内回りコースを使用。3コーナーの坂を越え、短い直線での勝負となる。',
      keyPoints: 'スタートから3コーナーまで距離がある。直線が短いため先行有利だが、坂の下りを利用した差しにも注意が必要。'
  ),
  CoursePreset(
      id: '08_shiba_soto_1400',
      venueCode: '08',
      venueName: '京都',
      distance: '芝1400(外)',
      direction: '右回り',
      straightLength: 404,
      courseLayout: '2コーナーからスタートし、外回りコースを使用。高低差4.3mの3コーナーの坂を越え、400m超の長い直線へ向かう。',
      keyPoints: 'スワンS(G2)の舞台。外回りコースは直線が長く、坂も高低差があるため差しも決まりやすい。末脚の持続力が問われる。'
  ),
  CoursePreset(
      id: '08_shiba_uchi_1600',
      venueCode: '08',
      venueName: '京都',
      distance: '芝1600(内)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: '2コーナー奥の引き込み線からスタート。ワンターンで内回りコースの3コーナーへ向かう。',
      keyPoints: 'スタートから3コーナーまでが長く、ペースが落ち着きやすい。直線が短いため、インコースをロスなく立ち回れる先行馬が有利。'
  ),
  CoursePreset(
      id: '08_shiba_soto_1600',
      venueCode: '08',
      venueName: '京都',
      distance: '芝1600(外)',
      direction: '右回り',
      straightLength: 404,
      courseLayout: '2コーナー奥の引き込み線からスタート。ワンターンで、3コーナーの坂を越え、長い直線で勝負が決まる。',
      keyPoints: 'マイルCS(G1)の舞台。紛れが少なく実力が反映されやすい。坂の下りを利用した加速力と、直線での末脚が重要。'
  ),
  CoursePreset(
      id: '08_shiba_soto_1800',
      venueCode: '08',
      venueName: '京都',
      distance: '芝1800(外)',
      direction: '右回り',
      straightLength: 404,
      courseLayout: '2コーナー奥の引き込み線からスタート。ワンターンで約900mの長いバックストレッチが特徴。',
      keyPoints: 'スタートから3コーナーまでが非常に長く、枠順の有利不利はほぼない。ペースが落ち着きやすく、瞬発力勝負になりやすい。'
  ),
  CoursePreset(
      id: '08_shiba_uchi_2000',
      venueCode: '08',
      venueName: '京都',
      distance: '芝2000(内)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: 'スタンド前からスタートし、内回りコースを一周する。タイトなコーナーと3コーナーの坂が特徴。',
      keyPoints: '秋華賞(G1)の舞台。スタートから1コーナーまでが短く内枠有利。器用さと立ち回りのうまさが求められる。'
  ),
  CoursePreset(
      id: '08_shiba_soto_2000',
      venueCode: '08',
      venueName: '京都',
      distance: '芝2000(外)',
      direction: '右回り',
      straightLength: 404,
      courseLayout: '向正面からのスタートで、外回りコースを使用する。3コーナーの坂を越え、長い直線での勝負。',
      keyPoints: 'コーナーが2回のみで、ゆったりとした流れになりやすい。スタミナと長い直線での瞬発力が問われる。'
  ),
  CoursePreset(
      id: '08_shiba_soto_2200',
      venueCode: '08',
      venueName: '京都',
      distance: '芝2200(外)',
      direction: '右回り',
      straightLength: 404,
      courseLayout: 'スタンド前からスタートし、外回りコースを一周する。3コーナーの坂越えと長い直線が待ち受ける。',
      keyPoints: 'エリザベス女王杯(G1)の舞台。スタミナと坂をこなすパワー、そして直線でのスピードが要求される総合力コース。'
  ),
  CoursePreset(
      id: '08_shiba_soto_2400',
      venueCode: '08',
      venueName: '京都',
      distance: '芝2400(外)',
      direction: '右回り',
      straightLength: 404,
      courseLayout: 'スタンド前からスタートし、外回りコースを一周する。3コーナーの坂越えと、400m超の平坦な直線が特徴。',
      keyPoints: '京都大賞典(G2)などの舞台。スタミナと坂をこなすパワー、そして直線でのスピードが要求される総合力コース。'
  ),
  CoursePreset(
      id: '08_shiba_soto_3000',
      venueCode: '08',
      venueName: '京都',
      distance: '芝3000(外)',
      direction: '右回り',
      straightLength: 404,
      courseLayout: '向正面からスタートし、外回りコースを一周半する。名物の3コーナーの坂を2度通過する。',
      keyPoints: '菊花賞(G1)の舞台。スタミナはもちろん、1周目の坂の下りからホームストレートでいかに折り合えるかが最大の鍵。'
  ),
  CoursePreset(
      id: '08_shiba_soto_3200',
      venueCode: '08',
      venueName: '京都',
      distance: '芝3200(外)',
      direction: '右回り',
      straightLength: 404,
      courseLayout: '向正面からスタートし、外回りコースを一周半する。3コーナーの坂を2度通過する、究極のスタミナコース。',
      keyPoints: '天皇賞(春)(G1)の舞台。日本最高峰のステイヤー決定戦。スタミナ、精神力、騎手の駆け引きの全てが試される。'
  ),

  // ダートコース (Dirt Courses)
  CoursePreset(
      id: '08_dirt_1000',
      venueCode: '08',
      venueName: '京都',
      distance: 'ダート1000',
      direction: '右回り',
      straightLength: 329,
      courseLayout: '向正面からのワンターン。すぐに3コーナーの坂を上り、下りながら平坦な直線へ向かう。',
      keyPoints: '直線が短く、先行力が絶対的に有利。坂の下りで勢いをつけられるかが鍵。'
  ),
  CoursePreset(
      id: '08_dirt_1100',
      venueCode: '08',
      venueName: '京都',
      distance: 'ダート1100',
      direction: '右回り',
      straightLength: 329,
      courseLayout: '向正面からのワンターン。1000mよりスタートが100m手前になる。',
      keyPoints: '1000mと同様、先行有利。距離が少し伸びる分、最後までスピードを持続させる必要がある。'
  ),
  CoursePreset(
      id: '08_dirt_1200',
      venueCode: '08',
      venueName: '京都',
      distance: 'ダート1200',
      direction: '右回り',
      straightLength: 329,
      courseLayout: '向正面からスタート。ダートコースにも設けられた3コーナーの坂を上り下りして、平坦な直線へ。',
      keyPoints: '先行力が基本だが、坂の下りを利用して差し馬も勢いをつけやすい。上がりの時計が速くなりやすい。'
  ),
  CoursePreset(
      id: '08_dirt_1400',
      venueCode: '08',
      venueName: '京都',
      distance: 'ダート1400',
      direction: '右回り',
      straightLength: 329,
      courseLayout: '2コーナー奥の芝地点からスタート。ワンターンで3コーナーの坂を越え、平坦な直線へ向かう。',
      keyPoints: '芝スタートのため外枠が有利。スピードに乗ったまま坂の下りを迎えられるため、ハイペースになりやすい。'
  ),
  CoursePreset(
      id: '08_dirt_1800',
      venueCode: '08',
      venueName: '京都',
      distance: 'ダート1800',
      direction: '右回り',
      straightLength: 329,
      courseLayout: 'スタンド前からスタートし、コースを一周する。3コーナーの坂越えが最大の特徴。',
      keyPoints: 'ダートの主要距離。スタートから1コーナーまでが短く、内枠の先行馬が有利。坂の下りでペースが上がりやすい。'
  ),
  CoursePreset(
      id: '08_dirt_1900',
      venueCode: '08',
      venueName: '京都',
      distance: 'ダート1900',
      direction: '右回り',
      straightLength: 329,
      courseLayout: 'スタンド前からスタート。1800mより100m奥からの発走で、1コーナーまでの距離が長くなる。',
      keyPoints: '平安S(G3)の舞台。1800mより先行争いが緩やかになり、スタミナもより要求される。'
  ),
  CoursePreset(
      id: '08_dirt_2600',
      venueCode: '08',
      venueName: '京都',
      distance: 'ダート2600',
      direction: '右回り',
      straightLength: 329,
      courseLayout: '向正面からスタートし、コースを一周半以上する長距離戦。3コーナーの坂を2度越える。',
      keyPoints: 'ダートの長距離戦。スタミナが最も重要で、馬の底力が試される。'
  ),

  // 障害コース (Steeplechase Courses)
  CoursePreset(
      id: '08_obstacle_dirt_2910',
      venueCode: '08',
      venueName: '京都',
      distance: '障害2910(ダート)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: '本馬場のダートコースからスタートし、障害コースへ。水ごうやいけ垣などを飛越する。',
      keyPoints: 'ダートスタートが序盤の展開に影響。障害飛越と平地力の両方が求められる。'
  ),
  CoursePreset(
      id: '08_obstacle_shiba_3170',
      venueCode: '08',
      venueName: '京都',
      distance: '障害3170(芝)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: '本馬場の芝コースからスタートし、障害コースへ。通常の障害コースを使用する。',
      keyPoints: '飛越の巧さとスタミナが問われる。3コーナーの坂がスタミナを消耗させる。'
  ),
  CoursePreset(
      id: '08_obstacle_dirt_3170',
      venueCode: '08',
      venueName: '京都',
      distance: '障害3170(ダート)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: '本馬場のダートコースからスタートし、障害コースへ。',
      keyPoints: 'ダートスタートが序盤の展開に影響。スタミナとパワーが求められる。'
  ),
  CoursePreset(
      id: '08_obstacle_shiba_3180_HJ',
      venueCode: '08',
      venueName: '京都',
      distance: '障害3180(芝)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: '3コーナーで分岐する大障害コースを使用。高低差0.8mのバンケット障害が名物。',
      keyPoints: '京都ハイジャンプ(J-G2)の舞台。バンケットの上り下りが最大の難関。飛越の巧さに加え、この特殊な障害をこなす器用さが求められる。'
  ),
  CoursePreset(
      id: '08_obstacle_dirt_3760',
      venueCode: '08',
      venueName: '京都',
      distance: '障害3760(ダート)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: 'ダートコースからスタートする長距離障害戦。障害コースを周回し、スタミナが試される。',
      keyPoints: '長丁場のため、スタミナと精神力が問われる。騎手のペース配分も重要。'
  ),
  CoursePreset(
      id: '08_obstacle_shiba_3930',
      venueCode: '08',
      venueName: '京都',
      distance: '障害3930(芝)',
      direction: '右回り',
      straightLength: 328,
      courseLayout: '芝コースからスタートする長距離障害戦。バンケットを含む大障害コースを使用する。',
      keyPoints: '京都ジャンプS(J-G3)の舞台。スタミナとバンケットをこなす能力が必須。'
  ),

  // ==========================================================================
  // HANSHIN RACECOURSE (09 阪神競馬場)
  // ==========================================================================

  // 芝コース (Turf Courses)
  CoursePreset(
      id: '09_shiba_uchi_1200',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝1200(内)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '内回りコースを使用。3コーナーから緩やかに下り、ゴール前に高低差1.8mの急坂が待ち構える。',
      keyPoints: 'セントウルS(G2)の舞台。前半は下り坂でペースが速くなりやすく、最後の急坂をこなすパワーが必須。'
  ),
  CoursePreset(
      id: '09_shiba_uchi_1400',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝1400(内)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '内回りコースを使用。ワンターンで、3コーナーから緩やかに下り、最後の直線で急坂を上る。',
      keyPoints: '阪神牝馬S(G2)の舞台。直線が短く急坂があるため、先行力と坂をこなすパワーが重要。'
  ),
  CoursePreset(
      id: '09_shiba_soto_1400',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝1400(外)',
      direction: '右回り',
      straightLength: 474,
      courseLayout: '外回りコースを使用するワンターン。直線が473.6mと長く、ゴール前に急坂が待ち構える。',
      keyPoints: 'フィリーズレビュー(G2)の舞台。直線が長く急坂もあるため、差し・追い込みも十分に届く。総合力が問われる。'
  ),
  CoursePreset(
      id: '09_shiba_soto_1600',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝1600(外)',
      direction: '右回り',
      straightLength: 474,
      courseLayout: '外回りコースを使用するワンターン。バックストレッチが長く、ゆったりしたコーナーを経て、長くて急坂のある直線へ。',
      keyPoints: '桜花賞(G1)、阪神JF(G1)の舞台。紛れが少なく、牝馬クラシックを占うにふさわしい実力勝負のコース。'
  ),
  CoursePreset(
      id: '09_shiba_soto_1800',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝1800(外)',
      direction: '右回り',
      straightLength: 474,
      courseLayout: '外回りコースを使用するワンターン。スタートから最初のコーナーまで非常に長く、最後の直線も長い。',
      keyPoints: '毎日杯(G3)の舞台。枠順の有利不利はほぼない。ペースが落ち着きやすく、直線での瞬発力と坂を駆け上がるパワーが求められる。'
  ),
  CoursePreset(
      id: '09_shiba_uchi_2000',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝2000(内)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '内回りコースを一周する。スタート直後に急坂があり、ゴール前にもう一度同じ坂を上る。',
      keyPoints: '大阪杯(G1)の舞台。2度の坂越えとタイトなコーナーが特徴のタフなコース。先行力とスタミナが重要。'
  ),
  CoursePreset(
      id: '09_shiba_uchi_2200',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝2200(内)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '内回りコースを一周する。スタートからゴールまで2度の坂越えと小回りをこなすレイアウト。',
      keyPoints: '宝塚記念(G1)の舞台。パワーと器用さが問われるグランプリコース。'
  ),
  CoursePreset(
      id: '09_shiba_soto_2400',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝2400(外)',
      direction: '右回り',
      straightLength: 474,
      courseLayout: '外回りコースを一周する。長い直線と急坂が待ち受ける、スタミナが問われるコース。',
      keyPoints: '神戸新聞杯(G2)の舞台。ゆったりした流れから最後の直線勝負になりやすく、スタミナと末脚の持続力が試される。'
  ),
  CoursePreset(
      id: '09_shiba_soto_2600',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝2600(外)',
      direction: '右回り',
      straightLength: 474,
      courseLayout: '外回りコースを一周する長距離戦。長い直線と急坂があり、スタミナが非常に重要。',
      keyPoints: 'スタミナと底力が試されるコース。ペースは落ち着きやすいが、最後の直線での末脚比べになる。'
  ),
  CoursePreset(
      id: '09_shiba_uchi_3000',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝3000(内)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '内回りコースを約1周半する長距離戦。急坂を2度越え、コーナーを6回通過する。',
      keyPoints: '阪神大賞典(G2)の舞台。スタミナと、何度もコーナーをロスなく回る器用さが求められる。'
  ),
  CoursePreset(
      id: '09_shiba_w_3200',
      venueCode: '09',
      venueName: '阪神',
      distance: '芝3200(外・内)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '外回りコースをスタートして1周し、その後内回りコースに入って最後の1周を回る特殊なレイアウト。',
      keyPoints: '天皇賞(春)(G1)の舞台。広大な外回りとタイトな内回りの両方を走り、坂を2度越える究極のスタミナコース。'
  ),

  // ダートコース (Dirt Courses)
  CoursePreset(
      id: '09_dirt_1200',
      venueCode: '09',
      venueName: '阪神',
      distance: 'ダート1200',
      direction: '右回り',
      straightLength: 353,
      courseLayout: '向正面からのワンターン。ゴール前200m地点から高低差1.6mの急坂が待ち構える。',
      keyPoints: '前半のペースが速くなりやすく、最後の坂で失速する馬も多い。スピードとパワーが要求される。'
  ),
  CoursePreset(
      id: '09_dirt_1400',
      venueCode: '09',
      venueName: '阪神',
      distance: 'ダート1400',
      direction: '右回り',
      straightLength: 353,
      courseLayout: '向正面の芝地点からスタート。緩やかな下りを経て、ゴール前に急坂が待ち構える。',
      keyPoints: '芝スタートのため外枠有利。前半は下り坂でスピードに乗りやすいが、最後の坂でパワーが試される。'
  ),
  CoursePreset(
      id: '09_dirt_1800',
      venueCode: '09',
      venueName: '阪神',
      distance: 'ダート1800',
      direction: '右回り',
      straightLength: 353,
      courseLayout: 'スタンド前からスタートし、コースを一周する。ゴール前に急坂が待ち構えるタフなコース。',
      keyPoints: 'ダートの主要距離。平坦な京都と違い、ゴール前の急坂がタフ。パワーと先行力が重要。'
  ),
  CoursePreset(
      id: '09_dirt_2000',
      venueCode: '09',
      venueName: '阪神',
      distance: 'ダート2000',
      direction: '右回り',
      straightLength: 353,
      courseLayout: 'スタンド前の芝地点からスタートし、コースを一周する。ゴール前には急坂が待ち構える。',
      keyPoints: '芝スタートのため外枠有利。1800mよりもスタミナが要求されるタフなコース。'
  ),
  CoursePreset(
      id: '09_dirt_2600',
      venueCode: '09',
      venueName: '阪神',
      distance: 'ダート2600',
      direction: '右回り',
      straightLength: 353,
      courseLayout: 'スタンド前からスタートし、コースを約1周半する長距離戦。急坂を2度越える過酷なレイアウト。',
      keyPoints: '圧倒的なスタミナとパワーが要求される。ペースは落ち着きやすく、ロングスパート性能が問われる。'
  ),

  // 障害コース (Steeplechase Courses)
  CoursePreset(
      id: '09_obstacle_dirt_2970',
      venueCode: '09',
      venueName: '阪神',
      distance: '障害2970(芝→ダ)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '芝コースからスタートし、襷コースを通り、ダートコースを横切るなど複雑なレイアウト。',
      keyPoints: '芝・ダート・襷コースを全て走破する適応力が求められる。水ごう障害も難関。'
  ),
  CoursePreset(
      id: '09_obstacle_shiba_3000',
      venueCode: '09',
      venueName: '阪神',
      distance: '障害3000(芝)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '内回りコースをベースに、襷コースを組み合わせたレイアウト。',
      keyPoints: '襷コースのアップダウンと、本馬場の障害飛越をこなす総合力が問われる。'
  ),
  CoursePreset(
      id: '09_obstacle_dirt_3110',
      venueCode: '09',
      venueName: '阪神',
      distance: '障害3110(芝→ダ)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '芝コースからスタートし、襷コースやダートコースを横切る複雑なレイアウト。',
      keyPoints: '芝・ダート・襷コースを全て走破する適応力が求められる。水ごう障害も難関。'
  ),
  CoursePreset(
      id: '09_obstacle_shiba_3140',
      venueCode: '09',
      venueName: '阪神',
      distance: '障害3140(芝)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '内回りコースと襷コースを組み合わせたレイアウト。',
      keyPoints: '阪神スプリングJ(J-G2)の舞台。襷コースの攻略と、最後の直線でのスタミナが重要。'
  ),
  CoursePreset(
      id: '09_obstacle_shiba_3800',
      venueCode: '09',
      venueName: '阪神',
      distance: '障害3800(芝)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '芝コースと襷コースを組み合わせた長距離戦。スタミナと飛越の正確性が求められる。',
      keyPoints: '長丁場のため、スタミナの消耗が激しい。騎手のペース配分が重要になる。'
  ),
  CoursePreset(
      id: '09_obstacle_shiba_3900',
      venueCode: '09',
      venueName: '阪神',
      distance: '障害3900(芝)',
      direction: '右回り',
      straightLength: 357,
      courseLayout: '芝コースと襷コースを組み合わせた長距離戦。',
      keyPoints: '阪神ジャンプS(J-G3)の舞台。スタミナと幾多の障害を越える精神力が試される。'
  ),

  // ==========================================================================
  // KOKURA RACECOURSE (10 小倉競馬場)
  // ==========================================================================

  // 芝コース (Turf Courses)
  CoursePreset(
      id: '10_shiba_1000',
      venueCode: '10',
      venueName: '小倉',
      distance: '芝1000',
      direction: '右回り',
      straightLength: 293,
      courseLayout: '向正面からのワンターン。スタート後すぐに下り坂に入り、平坦な直線へ向かうスピードコース。',
      keyPoints: 'ほぼ下り坂のため、JRA全コースの中でも特に時計が速くなりやすい。スタートダッシュとスピードが全てで、逃げ・先行馬が圧倒的に有利。'
  ),
  CoursePreset(
      id: '10_shiba_1200',
      venueCode: '10',
      venueName: '小倉',
      distance: '芝1200',
      direction: '右回り',
      straightLength: 293,
      courseLayout: '2コーナー奥のポケットからスタート。スタート後はほぼ下り坂で、スパイラルカーブを経て平坦な直線へ向かう。',
      keyPoints: 'CBC賞(G3)・北九州記念(G3)の舞台。JRA屈指の高速コースで、スピードの絶対値が問われる。枠順の有利不利は少なく、先行力が重要。'
  ),
  CoursePreset(
      id: '10_shiba_1700',
      venueCode: '10',
      venueName: '小倉',
      distance: '芝1700',
      direction: '右回り',
      straightLength: 293,
      courseLayout: 'スタンド前からスタートし、コースを一周する。スタート直後から2コーナーの丘へ上り、その後は下り坂と平坦な直線が続く。',
      keyPoints: 'JRA唯一の距離設定。アップダウンと小回りをこなす器用さが求められるトリッキーなコース。'
  ),
  CoursePreset(
      id: '10_shiba_1800',
      venueCode: '10',
      venueName: '小倉',
      distance: '芝1800',
      direction: '右回り',
      straightLength: 293,
      courseLayout: 'スタンド前からスタートし、コースを一周する。スタート直後から2コーナーの丘へ上り、その後は下り坂と平坦な直線が続く。',
      keyPoints: 'スタートから最初のコーナーまでが短いため内枠有利。2コーナーの丘でペースが緩みやすく、向正面での捲りが決まりやすい。'
  ),
  CoursePreset(
      id: '10_shiba_2000',
      venueCode: '10',
      venueName: '小倉',
      distance: '芝2000',
      direction: '右回り',
      straightLength: 293,
      courseLayout: 'スタンド前からスタートし、コースを一周する。1800mより200mスタートが下がり、1コーナーまでの距離が長くなる。',
      keyPoints: '小倉記念(G3)の舞台。1800mよりは枠順の有利不利が緩和される。2コーナーの丘でのペース判断と、早めの仕掛けが鍵を握る。'
  ),
  CoursePreset(
      id: '10_shiba_2600',
      venueCode: '10',
      venueName: '小倉',
      distance: '芝2600',
      direction: '右回り',
      straightLength: 293,
      courseLayout: 'スタンド前からスタートし、コースを一周半する。2コーナーの丘を2度上り下りするスタミナコース。',
      keyPoints: 'スタミナが最も重要。コーナーを6回通過するため、ロスなく立ち回れる器用さも求められる。'
  ),

  // ダートコース (Dirt Courses)
  CoursePreset(
      id: '10_dirt_1000',
      venueCode: '10',
      venueName: '小倉',
      distance: 'ダート1000',
      direction: '右回り',
      straightLength: 291,
      courseLayout: '向正面からのワンターン。2コーナーの丘の横からスタートし、下り坂を経て緩やかな上り勾配のある直線へ。',
      keyPoints: '下り坂でスピードに乗りやすく、先行争いが激化しやすい。スピードと、最後の坂を乗り切るパワーが必要。'
  ),
  CoursePreset(
      id: '10_dirt_1700',
      venueCode: '10',
      venueName: '小倉',
      distance: 'ダート1700',
      direction: '右回り',
      straightLength: 291,
      courseLayout: 'スタンド前からスタートし、コースを一周する。2コーナーの丘を越え、最後の直線には緩やかな上り坂がある。',
      keyPoints: 'ダートの主要距離。芝同様に先行有利。中団あたりから早めに動ける差し馬にもチャンスがある。'
  ),
  CoursePreset(
      id: '10_dirt_2400',
      venueCode: '10',
      venueName: '小倉',
      distance: 'ダート2400',
      direction: '右回り',
      straightLength: 291,
      courseLayout: 'スタンド前からスタートし、コースを一周半する長距離戦。2コーナーの丘と直線の坂を2度越えるタフなコース。',
      keyPoints: 'スタミナが絶対的に重要。ペースが落ち着きやすく、騎手のペース判断が問われる。'
  ),

  // 障害コース (Steeplechase Courses)
  CoursePreset(
      id: '10_obstacle_2860',
      venueCode: '10',
      venueName: '小倉',
      distance: '障害2860',
      direction: '右回り',
      straightLength: 293,
      courseLayout: '襷コースを含む専用コースで争われる。高低差2.76mのバンケット障害が名物。',
      keyPoints: '飛越の巧さが問われる。名物のバンケット障害をスムーズにこなせるかが勝負の鍵を握る。'
  ),
  CoursePreset(
      id: '10_obstacle_3390',
      venueCode: '10',
      venueName: '小倉',
      distance: '障害3390',
      direction: '右回り',
      straightLength: 293,
      courseLayout: '襷コースを含む専用コースを周回する長距離戦。名物のバンケットや水ごう障害を複数回飛越する。',
      keyPoints: '小倉サマージャンプ(J-G3)の舞台。スタミナと幾多の障害を越える精神力、そしてバンケットへの対応力が試される。'
  )
];