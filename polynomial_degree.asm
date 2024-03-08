global polynomial_degree


polynomial_degree:
; Na początku sprawdzamy, czy nasz wielomian jest wielomianem zerowym. 
	lea		rdx, [rsi-0x1]; zapisujemy na rdx kiedy skończyć pętlę
	xor 	eax, eax; zeruję eax, będziemy na nim trzymać indeks pętli
	jmp 	testing_elem
comparison:
	cmp 	rdx, rax; sprawdzamy warunek pętli
	je 		return_minus_one
	add 	rax, 0x1; rax++
	cmp 	rsi, rax; zwiększyliśmy rax i sprawdzamy czy się nie stał już równy n
	je 		checking_if_n_equals_one; return_one
testing_elem:
	mov 	ecx, DWORD [rdi+rax*4]; i-ty element tablicy zapisujemy na ecx
	test 	ecx, ecx; sprawdzamy,  czy i-ty element zapisany na ecx jest zerem
	je 		comparison
	jmp 	checking_if_n_equals_one
return_minus_one:
	mov 	eax, 0xffffffff; jeśli wielomian jest zerowy to zwracamy -1
	ret 


; Teraz wiemy, że nie wielomian nie jest zerowy.
; Będziemy sprawdzać czy n == 1
checking_if_n_equals_one:
	cmp 	rsi, 0x1; sprawdzamy czy n==1
	jne 	after_zeros_checking
	xor 	rax, rax; zwracamy 0
	ret


; Teraz będziemy szukać najmniejszej liczby podzielnej przez 64 większej od 32 + n (i zapiszemy to na rdx)
after_zeros_checking:
	lea		rdx, [rsi+0x20]; n+32
	test 	dl, 0x3f; sprawdzam podzielność przez 64
	je 		allocation
	shr 	rdx, 0x6; dzielimy na 64
	add 	rdx, 0x1
	shl 	rdx, 0x6; mnożymy przez 64


allocation:
	push 	rbx; będziemy w programie używać rejestru rbx,  więc odkładamy jego obecną wartość na stos
	push 	r13; będziemy w programie używać rejestru r13,  więc odkładamy jego obecną wartość na stos
	push	r14; będziemy w programie używać rejestru r14,  więc odkładamy jego obecną wartość na stos
	; Teraz będziemy chcieli przekopiować naszą tablicę na stos
	mov 	r9, rdx; najmniejsza liczba podzielna przez 64 większa od 32 + n
	mov 	r8, r9;
	shr 	r8, 0x6; dzielimy na 64,  (to jest ilość 64-bitowych kawałków w jednej liczbie)
	imul 	rdx, rsi; zapisuję na rdx ilość miejsca do zaalokowania na stosie
	shr 	rdx, 0x3; dzielimy na 8 (bo odejmujemy od stosu ilość bajtów a nie bitów)
	sub 	rsp, rdx; alokuję na stosie miejsce na naszą tablicę


; Zaczynamy kopiowanie tablicy na stos
	xor 	rax, rax; zeruję rax,  będzie to indeks pętli zewnętrznej
outer_loop:
	mov 	rcx, r8; indeks pętli wewnętrznej
	sub 	rcx, 0x1; ustawiamy na r8-1 (indeks pętli wewnętrznej będzie się zmniejszał przy kolejnych obrotach)
	mov 	r10, 0x1; zapisujemy,  że jesteśmy w pierwszym obrocie pętli wewnętrznej

inner_loop:
	mov 	r13, rax; przenosimy,  żeby nie zgubić indeksu
	imul 	r13, r8; r13 = i*r8
	lea 	r13, [r13+rcx*1]; r13 += rcx 
	cmp 	r10, 0x1;
	jne 	not_first_rotation
	mov 	r10, 0x0; zaznaczamy, że teraz już nie będzie pierwszy obrót pętli wewnętrznej
	movsxd 	r14, [rdi + rax*4]; r14 = y[rax] 
	mov 	[rsp + r13*8], r14;
	mov 	r11, r14
	shr 	r11, 63; zostawiamy tutaj tylko bit znaku
	neg 	r11
	jmp		end_of_inner_loop
not_first_rotation:
	mov 	[rsp + r13*8],  r11; wpisujemy znak
end_of_inner_loop:
	sub 	rcx, 0x1
	cmp 	rcx, -0x1; sprawdzam czy indeks jest >= 0
	jne 	inner_loop

	add 	rax, 0x1
	cmp 	rax, rsi; sprawdzamy czy indeks jest różny od n
	jne 	outer_loop


; Chcemy odejmować kolejne elementy tablicy: y[i] = y[i] - y[i+1]
; Potem będziemy sprawdzać,  czy wszystkie wartości w tablicy są równe
; Jeśli nie,  to powtarzamy odejmowanie 
; Szukany stopień wielomianu to ilość odejmowań,  które wykonamy
; np: dla tablicy y = {1,  4,  9,  16,  25,  36} mamy:
; przed pierwszym odejmowaniem: {1,  4,  9,  16,  25,  36}
; po pierwszym odejmowaniu: {-3,  -5,  -7,  -9,  -11}
; po drugim odejmowaniu: {2,  2,  2,  2}
; Wszystkie wartości są równe po dwóch odejmowaniach,  zatem szukany stopień to 2
; Oczywiście przy każdym kolejnym obrocie będziemy mieć o jedną liczbę do odejmowania mniej

; Zaczynamy odejmowanie:
	xor 	rax, rax; tu będziemy liczyć ilość wykonanych odejmowań (a tym samym na tej zmiennej powstanie wynik)
beg_of_while:
	mov 	r11, rsi; zapisujemy na r11 długość tablicy y
	sub 	r11, rax; w tym obrocie whilea będziemy chcieli iterować się po stosie po n-rax liczbach (to jest uwzględnienie faktu,
	;że przy każdym kolejnym obrocie będziemy mieć o jedną liczbę do odejmowania mniej)
	sub 	r11, 0x1; bo chcę iterwać się do przedostatniego elementu (będę rozważać różnicę między i-tym elementem a i+1)
	cmp		 r11, 0; jeśli została nam tylko jedna liczba, to skończyliśmy algorytm
	je 		the_end
	; Sprawdzanie,  czy wszystkie wartości w tablicy są równe:
	xor 	r10, r10; to będzie indeks zewnętrznej pętli

outer_loop_checking_for_equality:
	xor rcx, rcx; to będzie indeks wewnętrznej pętli

inner_loop_checking_for_equality:
	; 4 poniższe instrukcje ustawiają r13 = ( r10 * r8 + rcx )*8
	mov 	r13, r10
	imul 	r13, r8
	add 	r13, rcx
	imul 	r13, 0x8
	; 5 poniższych instrukcji ustawiaja r14 = ( (r10+1) * r8 + rcx )*8
	mov 	r14, r10
	add 	r14, 0x1
	imul 	r14, r8
	add 	r14, rcx
	imul 	r14, 0x8
	; Teraz będziemy porównywać
	mov 	r13, [rsp + r13*1]; przenosimy na r13 pierwszą porównywaną wartość ze stosu
	cmp 	r13, [rsp + r14*1]; porównujemy odpowiednie części liczb
	jne 	start_of_subtraction; komórka jest różna,  więc tablice nie są równe
	; Jeśli są równe to dalej porównujemy
	add 	rcx, 0x1;
	cmp 	rcx, r8; sprawdzamy warunek pętli wewnętrznej
	jne 	inner_loop_checking_for_equality

	add 	r10, 0x1;
	cmp 	r10, r11; sprawdzamy warunek pętli zewnętrznej (rax < n-rax-1)
	jne 	outer_loop_checking_for_equality

	; Jeśli doszłam do tego miejsca,  czyli końca tej pętli, to znaczy że wszystkie elementy tablicy są równe,
	; Zatem chcę teraz zwrócić ilość wykonanych obrotów whilea, ta wartość już jest zapisana na rax:
	add 	rsp, rdx; przywracamy początkową wartość stosu
	pop 	r14; przywracamy wartość rejestru r14
	pop 	r13; przywracamy wartość rejestru r13
	pop 	rbx; przywracamy wartość rejestru rbx
	ret


; Odejmowanie:
start_of_subtraction:
	xor 	r10, r10 ;to będzie indeks zewnętrznej pętli

outer_loop_subtraction:
	mov 	rcx, r8; to będzie indeks wewnętrznej pętli
	sub 	rcx, 0x1; rcx = r8-1
	mov 	rbx, 0x1; na rbx będziemy pamiętać,  czy flaga cf powinna być podniesiona przy kolejnym odejmowaniu czy nie
	;jeśli powinna być: rbx = 0
	;jeśli nie: rbx = 1
	;zatem na początku ustawiam na rbx = 1

inner_loop_subtraction:
	; 4 poniższe instrukcje ustawiają r13 = ( r10 * r8 + rcx )*8
	mov 	r13, r10
	imul 	r13, r8
	add 	r13, rcx
	imul 	r13, 0x8
	; 5 poniższych instrukcji ustawiaja r14 = ( (r10+1) * r8 + rcx )*8
	mov 	r14, r10
	add 	r14, 0x1
	imul 	r14, r8
	add 	r14, rcx
	imul 	r14, 0x8
	; r13 i r14 ustawione
	cmp 	rbx, 0x1; ustawiamy flagę cf w zależności od rbx
	mov 	r14, [rsp + r14]; przenoszę na r14 wartość ze stosu do odjęcia
	sbb 	[rsp + r13], r14; odejmujemy (i w razie potrzeby ustawiamy flagę cf)
	mov 	rbx, 0x1
	jnc 	the_rest_of_the_inner_loop
	xor 	rbx, rbx; zaznaczamy na rbx,  że flaga była podniesiona
the_rest_of_the_inner_loop:
	sub 	rcx, 0x1
	cmp 	rcx, -1; sprawdzam warunek pętli wewnętrznej (rcx >= 0)
	jne 	inner_loop_subtraction

	add 	r10, 0x1;
	cmp 	r10, r11; sprawdzamy warunek pętli (r10 < n-rax-1)
	jne 	outer_loop_subtraction

	add 	rax, 0x1
	jmp 	beg_of_while


the_end:
	add 	rsp, rdx
	pop 	r14
	pop 	r13
	pop 	rbx
	ret