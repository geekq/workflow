require 'spec_helper'
require 'debugger'
describe Article do

  context "new article" do
    before :all do
      @article = Article.new
    end

    it "should start in state new" do
      @article.should be_new
    end

    it "should have event called submit" do
      @article.current_state.events.keys.should =~ [:submit]
    end

    it "should be able to submit" do
      @article.can_submit?.should be true
    end
    
    it "should not be able to be reviewed" do
      @article.can_review?.should be false
    end
  end

  context "submitted article" do
    before :all do
      @article = Article.new
      @article.submit!
    end
    
    subject { @article }
    
    it { should be_awaiting_review }
    it { should have_event(:review) }
    it { should_not have_event(:impossible_event) }
    it { should have_event(:inevitable_event)}

    it "should not transition to impossible state" do
      @article.impossible_event!
      @article.should be_halted
      @article.halted_because.should == "error message"
    end

    it "should transition to inevitable_state" do
      @article.inevitable_event!
      @article.inevitable_state?.should be true
    end
  end
    
end
