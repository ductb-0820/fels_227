class Word < ApplicationRecord
  belongs_to :category
  has_many :answers, dependent: :destroy
  has_many :results, dependent: :destroy
  accepts_nested_attributes_for :answers, allow_destroy: true,
    reject_if: proc { |attributes| attributes["content"].blank? }
  validates :content, presence: true, length: {maximum: 255}
  before_validation :must_have_a_correct_answer, :must_have_min_answer,
    :dont_have_duplicate_answer

  scope :all_word, -> user_id{}
  scope :learned, -> user_id{where "id in
    (select word_id from answers where is_correct = '1' and id in
      (select answer_id from results where lesson_id in
        (select id from lessons where user_id = #{user_id})))"}
  scope :not_learn, -> user_id{where "id not in
    (select word_id from answers where is_correct = '1' and id in
      (select answer_id from results where lesson_id in
        (select id from lessons where user_id = #{user_id})))"}

  scope :group_by_month, -> start_month, end_month do
    where("date_trunc('month', created_at) <= '#{end_month}' AND
      date_trunc('month', created_at) >= '#{start_month}'")
    .group("to_char(created_at, 'YYYY-MM')")
    .order("to_char_created_at_yyyy_mm ASC")
  end

  private
  def must_have_a_correct_answer
    unless self.answers.
      select{|answer| answer.is_correct}.size == Settings.correct_answers_limit
      errors.add "", I18n.t(:must_choose_a_correct_answer)
    end
  end

  def must_have_min_answer
    unless self.answers.size >= Settings.default_answer_limit
      errors.add "", I18n.t(:must_choose_min_answer,
        min: Settings.default_answer_limit)
    end
  end

  def dont_have_duplicate_answer
    all_answer = []
    self.answers.each do |answer|
      all_answer << answer.content
    end
    duplicate_answer =
      all_answer.find_all { |answer| all_answer.count(answer) > 1 }
    unless duplicate_answer.size == 0
      errors.add "", I18n.t(:have_duplicate_answer,
        content: duplicate_answer.uniq!.join(","))
    end
  end
end
