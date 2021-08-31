#lang racket

(struct Int (value))
(struct Prim (op arg*))
;; alternative to Prim:
;;(struct Add (left right))
;;(struct Neg (value))
;;(struct Read ())

(define E1 (Int 42))
(define E2 (Prim 'read '()))
(define E3 (Prim '- (list E1)))
(define E4 (Prim '+ (list E3 (Int 5))))
(define E5 (Prim '+ (list E2 (Prim '- (list E2)))))

(define (list-max ls)
  (foldl max 0 ls))

(define (height e)
  (match e
    [(Int n) 1]
    [(Prim op e*)
     ( + 1 (for/fold ([curr-max 0])
                     ([h (map height e*)])
             (max curr-max h)))]
    ))

(height E1)
(height E2)
(height E3)
(height E4)
(height E5)
