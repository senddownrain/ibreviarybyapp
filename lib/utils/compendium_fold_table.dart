// GENERATED from Python `unicodedata` (NFD, combining marks removed) for the
// Latin, Greek and Cyrillic blocks. Dart has no built-in Unicode
// normalisation; this table reproduces `normalize('NFD')` + removing `\p{M}`
// from MyBrev `compendiumSearch.js` for every precomposed letter in those
// blocks (ё→е, й→и, ў→у, ї→і, á→a …). Do not edit by hand.

/// Precomposed letters, index-aligned with [kCompendiumFoldTargets].
const String kCompendiumFoldSources =
    'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíî'
    'ïñòóôõöùúûüýÿĀāĂăĄąĆćĈĉĊċČčĎďĒēĔĕĖėĘęĚěĜ'
    'ĝĞğĠġĢģĤĥĨĩĪīĬĭĮįİĴĵĶķĹĺĻļĽľŃńŅņŇňŌōŎŏŐő'
    'ŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽ'
    'žƠơƯưǍǎǏǐǑǒǓǔǕǖǗǘǙǚǛǜǞǟǠǡǢǣǦǧǨǩǪǫǬǭǮǯǰǴǵ'
    'ǸǹǺǻǼǽǾǿȀȁȂȃȄȅȆȇȈȉȊȋȌȍȎȏȐȑȒȓȔȕȖȗȘșȚțȞȟȦȧ'
    'ȨȩȪȫȬȭȮȯȰȱȲȳʹ;΅Ά·ΈΉΊΌΎΏΐΪΫάέήίΰϊϋόύώϓϔЀЁ'
    'ЃЇЌЍЎЙйѐёѓїќѝўѶѷӁӂӐӑӒӓӖӗӚӛӜӝӞӟӢӣӤӥӦӧӪӫӬӭ'
    'ӮӯӰӱӲӳӴӵӸӹḀḁḂḃḄḅḆḇḈḉḊḋḌḍḎḏḐḑḒḓḔḕḖḗḘḙḚḛḜḝ'
    'ḞḟḠḡḢḣḤḥḦḧḨḩḪḫḬḭḮḯḰḱḲḳḴḵḶḷḸḹḺḻḼḽḾḿṀṁṂṃṄṅ'
    'ṆṇṈṉṊṋṌṍṎṏṐṑṒṓṔṕṖṗṘṙṚṛṜṝṞṟṠṡṢṣṤṥṦṧṨṩṪṫṬṭ'
    'ṮṯṰṱṲṳṴṵṶṷṸṹṺṻṼṽṾṿẀẁẂẃẄẅẆẇẈẉẊẋẌẍẎẏẐẑẒẓẔẕ'
    'ẖẗẘẙẛẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂ'
    'ểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪ'
    'ừỬửỮữỰựỲỳỴỵỶỷỸỹἀἁἂἃἄἅἆἇἈἉἊἋἌἍἎἏἐἑἒἓἔἕἘἙἚ'
    'ἛἜἝἠἡἢἣἤἥἦἧἨἩἪἫἬἭἮἯἰἱἲἳἴἵἶἷἸἹἺἻἼἽἾἿὀὁὂὃὄ'
    'ὅὈὉὊὋὌὍὐὑὒὓὔὕὖὗὙὛὝὟὠὡὢὣὤὥὦὧὨὩὪὫὬὭὮὯὰάὲέὴ'
    'ήὶίὸόὺύὼώᾀᾁᾂᾃᾄᾅᾆᾇᾈᾉᾊᾋᾌᾍᾎᾏᾐᾑᾒᾓᾔᾕᾖᾗᾘᾙᾚᾛᾜᾝᾞ'
    'ᾟᾠᾡᾢᾣᾤᾥᾦᾧᾨᾩᾪᾫᾬᾭᾮᾯᾰᾱᾲᾳᾴᾶᾷᾸᾹᾺΆᾼι῁ῂῃῄῆῇῈΈῊΉ'
    'ῌ῍῎῏ῐῑῒΐῖῗῘῙῚΊ῝῞῟ῠῡῢΰῤῥῦῧῨῩῪΎῬ῭΅`ῲῳῴῶῷῸΌ'
    'ῺΏῼ´';

/// Base letter of each entry in [kCompendiumFoldSources].
const String kCompendiumFoldTargets =
    'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiii'
    'inooooouuuuyyAaAaAaCcCcCcCcDdEeEeEeEeEeG'
    'gGgGgGgHhIiIiIiIiIJjKkLlLlLlNnNnNnOoOoOo'
    'RrRrRrSsSsSsSsTtTtUuUuUuUuUuUuWwYyYZzZzZ'
    'zOoUuAaIiOoUuUuUuUuUuAaAaÆæGgKkOoOoƷʒjGg'
    'NnAaÆæØøAaAaEeEeIiIiOoOoRrRrUuUuSsTtHhAa'
    'EeOoOoOoOoYyʹ;¨Α·ΕΗΙΟΥΩιΙΥαεηιυιυουωϒϒЕЕ'
    'ГІКИУИиеегікиуѴѵЖжАаАаЕеӘәЖжЗзИиИиОоӨөЭэ'
    'УуУуУуЧчЫыAaBbBbBbCcDdDdDdDdDdEeEeEeEeEe'
    'FfGgHhHhHhHhHhIiIiKkKkKkLlLlLlLlMmMmMmNn'
    'NnNnNnOoOoOoOoPpPpRrRrRrRrSsSsSsSsSsTtTt'
    'TtTtUuUuUuUuUuVvVvWwWwWwWwWwXxXxYyZzZzZz'
    'htwyſAaAaAaAaAaAaAaAaAaAaAaAaEeEeEeEeEeE'
    'eEeEeIiIiOoOoOoOoOoOoOoOoOoOoOoOoUuUuUuU'
    'uUuUuUuYyYyYyYyααααααααΑΑΑΑΑΑΑΑεεεεεεΕΕΕ'
    'ΕΕΕηηηηηηηηΗΗΗΗΗΗΗΗιιιιιιιιΙΙΙΙΙΙΙΙοοοοο'
    'οΟΟΟΟΟΟυυυυυυυυΥΥΥΥωωωωωωωωΩΩΩΩΩΩΩΩααεεη'
    'ηιιοουυωωααααααααΑΑΑΑΑΑΑΑηηηηηηηηΗΗΗΗΗΗΗ'
    'ΗωωωωωωωωΩΩΩΩΩΩΩΩαααααααΑΑΑΑΑι¨ηηηηηΕΕΗΗ'
    'Η᾿᾿᾿ιιιιιιΙΙΙΙ῾῾῾υυυυρρυυΥΥΥΥΡ¨¨`ωωωωωΟΟ'
    'ΩΩΩ´';
