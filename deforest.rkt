#lang racket

;; Let's write up the example optimized "all" for practice.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; NOTE(jordan): ’ codepoint is 2019.
(define (all’ p xs)
  (if (empty? xs) #t
      (and (p (first xs)) (all’ p (rest xs)))))

;; That's a "deforested" program. This is what we'd rather write:
;; (Excluding the && hack to make `and` not think it's special...)
(define (&& a b) (and a b))
(define (crude-all p xs) (foldr && #t (map p xs)))

;; ... Alternatively, it just occurred to me we can use andmap. That's more rackety.
(define (all p xs) (andmap p xs))

(and (all number? '(5 5 5)) (all’ number? '(5 5 5)))

;; Okay next up. Let's define build.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (build g) (g cons '()))
;; ^^ Essentially: partial application of g with cons and '().!

;; Let's do the from example.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; from
(define (from a b)
  (if (> a b)
    '()
    (cons a (from (+ a 1) b))))

;; from’
(define (from’ a b)
  (λ (c n)
     (if (> a b)
       n
       (c a ((from’ (+ a 1) b) c n)))))

;; Verify from’ is spiritually equal to from.
(andmap equal? (from 0 5) (build (from’ 0 5)))

;; Nice! We can see that these things work, just like the paper said. (Whodathunk.)
;; Let's build the (build) stdlib.
(define (map’ f xs)
  (build (λ (c n) (foldr (λ (a b) (c (f a) b)) n xs))))

(define (filter’ f xs)
  (build (λ (c n) (foldr (λ (a b) (if (f a) (c a b) b)) n xs))))

(define (++’ xs ys)
  (build (λ (c n) (foldr c (foldr c n ys) xs))))

(define (concat’ xs)
  (build (λ (c n) (foldr (λ (x y) (foldr c y x)) n xs))))

;; Seems non-trivial to create an infinite list in Racket to mimic repeat.
;; Would I need Streams here? Not that important.
#| (define (repeat’ x)      |#
#|   (build (λ (c n) ...))) |#

#| (repeat’ 5)              |#

(define (zip’ xs ys)
  (build (λ (c n) (if (and (not (empty? xs)) (not (empty? ys)))
                      (c `(,(first xs) ,(first ys)) (zip’ (rest xs) (rest ys)))
                      n))))

(define nil’ (build (λ (c n) n)))

(define (cons’ x xs) (build (λ (c n) (c x (foldr c n xs)))))

;; Verify loosely/informally that these behave more-or-less as expected.
(map’ - '(1 2 3))

(filter’ number? '(1 2 "a" "b" 4 "c"))

(++’ '(1 2) '(3 4))

(concat’ '((1) (2 3) (4 5 6)))

(zip’ '(1 2 3) '("a" "b" "c"))

nil’

(cons’ 5 '(4 3 2 1))

;; Now let's do some kind of actual work.
;; Convert unlines to use build-based library functions.
;; In Haskell, strings are lists, which means racket don't do that... So we fake it.
(define (unlines ls) (flatten (map (λ (l) (append `(,l) '("\n"))) ls)))

(unlines '("abcjks jdkl aflkjdsa jfls" "jfdslajf kslaj flskdajf" " fjdsaklfj lksaj fds"))

;; flatten -> concat’
;; append  -> append’

(define (libfn->buildfn exp)
  (match exp
    [`(flatten ,xs) `(concat’ ,(libfn->buildfn xs))]
    [`(append ,xs ,ys) `(++’ ,(libfn->buildfn xs) ,(libfn->buildfn ys))]
    [`(map ,f ,xs) `(map’ ,(libfn->buildfn f) ,(libfn->buildfn xs))]
    [`(λ ,args ,body) `(λ ,args ,(libfn->buildfn body))]
    [e e]))

;; Racket namespace nonsense...
(define-namespace-anchor a)
(let ([ns (namespace-anchor->namespace a)])
  (letrec ([ls '("asjfkld fdsajkf " " Afdsjkalfjdlksa f"  "fdsjalkf jlksafj dslka")]
           [bexp (libfn->buildfn `(flatten (map (λ (l) (append `(,l) '("\n"))) ',ls)))])
    (eval bexp ns)))
;; But hey, the transformation is (roughly) working on the body of unlines.