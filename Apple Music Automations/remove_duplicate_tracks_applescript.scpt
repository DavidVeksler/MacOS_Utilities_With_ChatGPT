FasdUAS 1.101.10   ��   ��    k             l    � ����  O     �  	  k    � 
 
     l   ��  ��      Get a list of all tracks     �   2   G e t   a   l i s t   o f   a l l   t r a c k s      r        n    
    2    
��
�� 
cTrk  4    �� 
�� 
cLiP  m    ����   o      ���� 0 	tracklist 	trackList      l   ��������  ��  ��        l   ��  ��    < 6 Create a list to store unique track names and artists     �   l   C r e a t e   a   l i s t   t o   s t o r e   u n i q u e   t r a c k   n a m e s   a n d   a r t i s t s      r       !   J    ����   ! o      ���� "0 tracklistunique trackListUnique   " # " l   ��������  ��  ��   #  $ % $ l   �� & '��   & . ( Create a list to store duplicate tracks    ' � ( ( P   C r e a t e   a   l i s t   t o   s t o r e   d u p l i c a t e   t r a c k s %  ) * ) r     + , + J    ����   , o      ���� "0 duplicatetracks duplicateTracks *  - . - l   ��������  ��  ��   .  / 0 / l   �� 1 2��   1 * $ Initialize a counter for duplicates    2 � 3 3 H   I n i t i a l i z e   a   c o u n t e r   f o r   d u p l i c a t e s 0  4 5 4 r     6 7 6 m    ����   7 o      ����  0 duplicatecount duplicateCount 5  8 9 8 l   ��������  ��  ��   9  : ; : l   �� < =��   < ' ! Loop over each track in the list    = � > > B   L o o p   o v e r   e a c h   t r a c k   i n   t h e   l i s t ;  ? @ ? X    g A�� B A Q   + b C D E C k   . Q F F  G H G l  . .�� I J��   I 4 . Create a key with the track's name and artist    J � K K \   C r e a t e   a   k e y   w i t h   t h e   t r a c k ' s   n a m e   a n d   a r t i s t H  L M L r   . 9 N O N c   . 7 P Q P l  . 5 R���� R b   . 5 S T S n   . 1 U V U 1   / 1��
�� 
pnam V o   . /���� 0 currenttrack currentTrack T n   1 4 W X W 1   2 4��
�� 
pArt X o   1 2���� 0 currenttrack currentTrack��  ��   Q m   5 6��
�� 
TEXT O o      ���� 0 trackkey trackKey M  Y Z Y l  : :��������  ��  ��   Z  [ \ [ l  : :�� ] ^��   ] / ) Check if this track has been seen before    ^ � _ _ R   C h e c k   i f   t h i s   t r a c k   h a s   b e e n   s e e n   b e f o r e \  `�� ` Z   : Q a b�� c a E   : = d e d o   : ;���� "0 tracklistunique trackListUnique e o   ; <���� 0 trackkey trackKey b k   @ J f f  g h g l  @ @�� i j��   i M G If it has, increment the duplicates counter and add to duplicates list    j � k k �   I f   i t   h a s ,   i n c r e m e n t   t h e   d u p l i c a t e s   c o u n t e r   a n d   a d d   t o   d u p l i c a t e s   l i s t h  l m l r   @ E n o n [   @ C p q p o   @ A����  0 duplicatecount duplicateCount q m   A B����  o o      ����  0 duplicatecount duplicateCount m  r�� r r   F J s t s o   F G���� 0 currenttrack currentTrack t n       u v u  ;   H I v o   G H���� "0 duplicatetracks duplicateTracks��  ��   c k   M Q w w  x y x l  M M�� z {��   z 6 0 If it hasn't, add it to the list of seen tracks    { � | | `   I f   i t   h a s n ' t ,   a d d   i t   t o   t h e   l i s t   o f   s e e n   t r a c k s y  }�� } r   M Q ~  ~ o   M N���� 0 trackkey trackKey  n       � � �  ;   O P � o   N O���� "0 tracklistunique trackListUnique��  ��   D R      �� ���
�� .ascrerr ****      � **** � o      ���� 0 errmsg errMsg��   E k   Y b � �  � � � l  Y Y�� � ���   �    Log any errors that occur    � � � � 4   L o g   a n y   e r r o r s   t h a t   o c c u r �  ��� � I  Y b�� ���
�� .ascrcmnt****      � **** � b   Y ^ � � � m   Y \ � � � � � & A n   e r r o r   o c c u r r e d :   � o   \ ]���� 0 errmsg errMsg��  ��  �� 0 currenttrack currentTrack B o    ���� 0 	tracklist 	trackList @  � � � l  h h��������  ��  ��   �  � � � l  h h�� � ���   � 6 0 Now, delete the duplicate tracks and count them    � � � � `   N o w ,   d e l e t e   t h e   d u p l i c a t e   t r a c k s   a n d   c o u n t   t h e m �  � � � r   h m � � � m   h i����   � o      ���� 0 removedcount removedCount �  � � � X   n � ��� � � Q   ~ � � � � � k   � � � �  � � � I  � ��� ���
�� .coredelonull���     obj  � o   � ����� 0 tracktodelete trackToDelete��   �  ��� � r   � � � � � [   � � � � � o   � ����� 0 removedcount removedCount � m   � �����  � o      ���� 0 removedcount removedCount��   � R      �� ���
�� .ascrerr ****      � **** � o      ���� 0 errmsg errMsg��   � I  � ��� ���
�� .ascrcmnt****      � **** � b   � � � � � m   � � � � � � � P A n   e r r o r   o c c u r r e d   w h i l e   d e l e t i n g   t r a c k :   � o   � ����� 0 errmsg errMsg��  �� 0 tracktodelete trackToDelete � o   q r���� "0 duplicatetracks duplicateTracks �  � � � l  � ���������  ��  ��   �  � � � l  � ��� � ���   � R L Display a message with the number of duplicates detected and tracks removed    � � � � �   D i s p l a y   a   m e s s a g e   w i t h   t h e   n u m b e r   o f   d u p l i c a t e s   d e t e c t e d   a n d   t r a c k s   r e m o v e d �  ��� � I  � ��� ���
�� .sysodlogaskr        TEXT � b   � � � � � b   � � � � � b   � � � � � l  � � ����� � c   � � � � � o   � �����  0 duplicatecount duplicateCount � m   � ���
�� 
TEXT��  ��   � m   � � � � � � � ,   d u p l i c a t e s   d e t e c t e d .   � l  � � ����� � c   � � � � � o   � ����� 0 removedcount removedCount � m   � ���
�� 
TEXT��  ��   � m   � � � � � � �     t r a c k s   r e m o v e d .��  ��   	 m      � ��                                                                                      @ alis    ,  Macintosh HD               ���BD ����	Music.app                                                      �������        ����  
 cu             Applications   /:System:Applications:Music.app/   	 M u s i c . a p p    M a c i n t o s h   H D  System/Applications/Music.app   / ��  ��  ��     ��� � l     ��������  ��  ��  ��       �� � ���   � ��
�� .aevtoappnull  �   � **** � �� ����� � ���
�� .aevtoappnull  �   � **** � k     � � �  ����  ��  ��   � �������� 0 currenttrack currentTrack�� 0 errmsg errMsg�� 0 tracktodelete trackToDelete �  �����������������������~�}�|�{ ��z�y�x � � ��w
�� 
cLiP
�� 
cTrk�� 0 	tracklist 	trackList�� "0 tracklistunique trackListUnique�� "0 duplicatetracks duplicateTracks��  0 duplicatecount duplicateCount
�� 
kocl
�� 
cobj
�� .corecnte****       ****
�� 
pnam
� 
pArt
�~ 
TEXT�} 0 trackkey trackKey�| 0 errmsg errMsg�{  
�z .ascrcmnt****      � ****�y 0 removedcount removedCount
�x .coredelonull���     obj 
�w .sysodlogaskr        TEXT�� �� �*�k/�-E�OjvE�OjvE�OjE�O K�[��l 	kh   (��,��,%�&E�O�� �kE�O��6FY ��6FW X  a �%j [OY��OjE` O 7�[��l 	kh  �j O_ kE` W X  a �%j [OY��O��&a %_ �&%a %j Uascr  ��ޭ