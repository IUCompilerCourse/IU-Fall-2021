#lang racket
(require "utilities.rkt")
(require "interp-Rint.rkt")

;; 42
(define E1 (Int 42))                    

;; (read)
(define E2 (Prim 'read '()))            

;; (- 42)
(define E3 (Prim '- (list E1)))

;; (+ (- 42) 5)
(define E4 (Prim '+ (list E3 (Int 5)))) 

;; (+ (read) (- (read)))
(define E5 (Prim '+ (list E2 (Prim '- (list E2))))) 

(interp-Rint (Program '() E1))
(interp-Rint (Program '() E2))
(interp-Rint (Program '() E3))
(interp-Rint (Program '() E4))
(interp-Rint (Program '() E5))
