
(in-package :pddl.macro-action.test)
(in-suite :pddl.macro-action)

(define (domain logistics)
  (:requirements :strips)
  (:predicates (truck ?t) (at ?t ?a) (connected ?x ?y))
  (:action move
           :parameters (?t ?x ?y)
           :precondition (and (truck ?t) (at ?t ?x) (connected ?x ?y))
           :effect (and (not (at ?t ?x)) (at ?t ?y))))

(define (problem logistics-prob)
  (:domain logistics)
  (:objects t1 a b c d)
  (:init (truck t1) (at t1 a) (connected a b) (connected b c))
  (:goal (at t1 c)))

(defun inv (fn)
  (lambda (a b)
    (funcall fn b a)))

(def-fixture check-macro ()
  (let* ((*domain* logistics)
         (*problem* logistics-prob)
         (args1 (list (object *problem* :t1)
                      (object *problem* :a)
                      (object *problem* :b)))
         (args2 (list (object *problem* :t1)
                      (object *problem* :b)
                      (object *problem* :c)))
         (ga1 (ground-action (action *domain* :move) args1))
         (ga2 (ground-action (action *domain* :move) args2))
         (result (reduce (inv #'apply-ground-action)
                         (list ga1 ga2)
                         :initial-value (init *problem*))))
    (flet ((ground-action (&rest args)
             (handler-bind ((error
                             (lambda (c)
                               (declare (ignore c))
                               (when-let ((r (find-restart 'ignore)))
                                 (invoke-restart r)))))
               (apply #'ground-action args))))
      (&body))))

(test (merge-action :fixture check-macro)
  (let ((m (merge-ground-actions ga1 ga2)))
    (describe m)
    (print (positive-preconditions m))
    (print (add-list m))
    (print (delete-list m))
    (is (= 4 (length (parameters m))))
    (is (= 4 (length (positive-preconditions m))))
    (is (= 1 (length (add-list m))))
    (is (= 2 (length (delete-list m))))
    (is (set-equal result (apply-ground-action m (init *problem*))
                   :test #'eqstate))))

(test (conflict :fixture check-macro)
  (let* ((args3 (list (object *problem* :t1)
                      (object *problem* :a)
                      (object *problem* :c)))
         (ga3 (ground-action (action *domain* :move) args3)))
    (is-true (conflict ga1 ga3))
    (is-false (conflict ga1 ga2))))

(test (ground-macro-action :fixture check-macro)
  (let ((gm (ground-macro-action (vector ga1 ga2))))
    (is (set-equal result
                   (apply-ground-action gm (init *problem*))
                   :test #'eqstate))
    (is-false (assign-ops gm))))

(test (nullary-macro-action :fixture check-macro)
  (let ((gm (nullary-macro-action (vector ga1 ga2))))
    (is (set-equal result
                   (apply-ground-action gm (init *problem*))
                   :test #'eqstate))
    (is-false (assign-ops gm))))

(test (add-costs :fixture check-macro)
  (let ((gm (ground-macro-action (vector ga1 ga2))))
    (let ((newdomain (shallow-copy *domain*
                                   :actions (append (actions *domain*)
                                                    (list gm)))))
      (let ((cost-domain (add-costs newdomain)))
        (iter (for a in (actions cost-domain))
              (if (typep a 'ground-macro-action)
                  (is (= 2 (increase (first (assign-ops a)))))
                  (is (= 1 (increase (first (assign-ops a))))))))))
  (let ((m (nullary-macro-action (vector ga1 ga2))))
    (let ((newdomain (shallow-copy *domain*
                                   :actions (append (actions *domain*)
                                                    (list m)))))
      (let ((cost-domain (add-costs newdomain)))
        (iter (for a in (actions cost-domain))
              (if (typep a 'macro-action)
                  (is (= 2 (increase (first (assign-ops a)))))
                  (is (= 1 (increase (first (assign-ops a)))))))))))

(test (decode-macro :fixture check-macro)
  (let* ((gm (ground-macro-action (vector ga1 ga2)))
         (ga (change-class (shallow-copy gm) 'pddl-ground-action)) ;; read from the plan flagment
         (decoded-actions (pddl.macro-action::decode-action gm ga)))
    (is (= 2 (length decoded-actions)))
    (is (set-equal result
                   (reduce (inv #'apply-ground-action)
                           decoded-actions
                           :initial-value (init *problem*))
                   :test #'eqstate))
    (let ((plan (pddl-plan :actions (vector ga))))
      (is (= 2 (length (actions (decode-plan gm plan))))))))

;; (test (ignore-environment :fixture check-macro)
;;   (let ((env-obj (list (object *problem* :a)
;;                        (object *problem* :b)
;;                        (object *problem* :c)
;;                        (object *problem* :d)))
;;         (gm (ground-macro-action (vector ga1 ga2))))
;;     (let ((m (lift-action gm env-obj)
;;     (multiple-value-bind (m alist) 
;;       (print m)
;;       (print alist)
;;       (is (= 1 (length (parameters m))))
;;       (is (= 5 (length alist)))
;;       (print (actions m))
;;       (is (= 4 (length (objects-in-macro m))))
;;       (is (= 4 (length (constants-in-macro m))))
;;       (iter (for pa in-vector (actions m)) ; partial action
;;             (is (= 3 (length (parameters pa)))))
;;       (let* ((truck (object *problem* :t1))
;;              (*domain*
;;               (shallow-copy
;;                *domain*
;;                :constants (append (mapcar (lambda (x) (cdr (assoc x alist)))
;;                                           env-obj)
;;                                   (constants *domain*))))
;;              (gm (ground-action m (list truck)))
;;              (decoded-actions (pddl.macro-action::decode-action m gm))
;;              (plan (pddl-plan :actions (vector gm))))
;;         (print decoded-actions)
;;         (is (= 2 (length decoded-actions)))
;;         (is (set-equal result
;;                        (reduce (inv #'apply-ground-action)
;;                                decoded-actions
;;                                :initial-value (init *problem*))
;;                        :test #'eqstate))
;;         (is (= 2 (length (actions (decode-plan m plan)))))))))


;; (defun tt ()
;;   (let* ((*domain* logistics)
;;          (*problem* logistics-prob)
;;          (args1 (list (object *problem* :t1)
;;                       (object *problem* :a)
;;                       (object *problem* :b)))
;;          (args2 (list (object *problem* :t1)
;;                       (object *problem* :b)
;;                       (object *problem* :c)))
;;          (ga1 (ground-action (action *domain* :move) args1))
;;          (ga2 (ground-action (action *domain* :move) args2))
;;          #+nil
;;          (result (reduce (inv #'apply-ground-action)
;;                          (list ga1 ga2)
;;                          :initial-value (init *problem*))))
;;     (flet ((ground-action (&rest args)
;;              (handler-bind ((error
;;                              (lambda (c)
;;                                (declare (ignore c))
;;                                (when-let ((r (find-restart 'ignore)))
;;                                  (invoke-restart r)))))
;;                (apply #'ground-action args))))
;;       (let ((env-obj (list (object *problem* :a)
;;                            (object *problem* :b)
;;                            (object *problem* :c))))
;;         (multiple-value-bind (m alist)
;;             (macro-action (vector ga1 ga2) env-obj)
;;           (print alist)
;;           (let* ((truck (object *problem* :t1))
;;                  (newconst (append (mapcar (lambda (x) (cdr (assoc x alist)))
;;                                            env-obj)
;;                                    (constants *domain*)))
;;                  (*domain*
;;                   (shallow-copy *domain* :constants newconst))
;;                  (gm (ground-action m (list truck)))
;;                  (decoded-actions (pddl.macro-action::decode-action m gm)))
;;             decoded-actions))))))
