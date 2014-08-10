
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
  (:objects t1 a b c)
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
                               (when-let ((r (find-restart 'ignore)))
                                 (invoke-restart r)))))
               (apply #'ground-action args))))
      (&body))))

(test (merge-action :fixture check-macro)
  (let ((m (merge-ground-actions ga1 ga2)))
    (is (= 4 (length (parameters m))))
    (is (= 4 (length (positive-preconditions m))))
    (is (= 1 (length (add-list m))))
    (is (= 1 (length (delete-list m))))
    (is (set-equal result (apply-ground-action m (init *problem*))
                   :test #'eqstate))))

(test (macro-action :fixture check-macro)
  (multiple-value-bind (m alist) (macro-action (list ga1 ga2))
    (is (set-equal result
                   (apply-ground-action (ground-action m (mapcar #'car alist))
                                        (init *problem*))
                   :test #'eqstate))))

(test (decode-macro :fixture check-macro)
  (multiple-value-bind (m alist) (macro-action (list ga1 ga2))
    (let* ((gm (ground-action m (mapcar #'car alist)))
           (decoded-actions (pddl.macro-action::decode-action m gm)))
      (is (= 2 (length decoded-actions)))
      (is (set-equal result
                     (reduce (inv #'apply-ground-action)
                             decoded-actions
                             :initial-value (init *problem*))
                     :test #'eqstate))
      (let ((plan (pddl-plan :actions (vector gm))))
        (is (= 2 (length (actions (decode-plan m plan)))))))))

