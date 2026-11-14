/// Credits for every bundled photo, from the licence details each source
/// publishes. Every photo here was cropped and resized.
class PhotoCredit {
  const PhotoCredit({
    required this.description,
    required this.author,
    required this.license,
    required this.source,
  });

  final String description;
  final String author;
  final String license;
  final String source;
}

const photoCredits = [
  PhotoCredit(
    description: 'Patan Durbar Square, Lalitpur',
    author: 'Bijay Chaurasia',
    license: 'CC BY-SA 4.0',
    source:
        'https://commons.wikimedia.org/wiki/File:Patan_Durbar_Square-2644.jpg',
  ),
  PhotoCredit(
    description: 'Boudhanath Stupa, Kathmandu',
    author: 'Bernard Gagnon',
    license: 'CC BY-SA 4.0',
    source: 'https://commons.wikimedia.org/wiki/File:Boudhanath_stupa,_Kathmandu_01.jpg',
  ),
  PhotoCredit(
    description: 'Patan Durbar Square, Lalitpur',
    author: 'Sworna Maharjan',
    license: 'CC BY-SA 4.0',
    source:
        'https://commons.wikimedia.org/wiki/File:Patan_Durbar_Square_pic.jpg',
  ),
  PhotoCredit(
    description: 'Nyatapola Temple, Bhaktapur',
    author: 'shankar s.',
    license: 'CC BY 2.0',
    source: 'https://commons.wikimedia.org/wiki/File:Nyatapola_temple_in_the_Bhaktapur_Durbar_Sqr._(49737973468).jpg',
  ),
  PhotoCredit(
    description: 'Phewa Lake and the Annapurna range, Pokhara',
    author: 'Jean-Marie Hullot',
    license: 'CC BY 2.0',
    source: 'https://commons.wikimedia.org/wiki/File:Phewa_Lake_in_Pokhara_(15715573565).jpg',
  ),
  PhotoCredit(
    description: 'Annapurna South and Machhapuchhre from Sarangkot',
    author: 'Bijay Chaurasia',
    license: 'CC BY-SA 4.0',
    source: 'https://commons.wikimedia.org/wiki/File:View_of_Annapurna_South_and_Machapuchare_from_Sarangkot,_Nepal-WLV-1659.jpg',
  ),
];
