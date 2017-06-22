#!/usr/bin/env ruby

require 'rubygems'
require 'thor'
require 'trello'
#require 'medium'
require 'medium_sdk'
require 'yaml'
require 'pp'

Encoding.default_external = "UTF-8" if Object.const_defined?('Encoding')

class Manager < Thor
  include Thor::Actions
  @medium_client = nil
  @@title_base = "Top Security and Privacy News: Scrambled Bits Vol."

  class_option :debug, :desc => 'Turn on debug logging', :type => :boolean, :aliases => '-d'

  def initialize(args = [], options = {}, config = {})
    super(args, options, config)
    creds = YAML::load_file('.credentials')
    Trello.configure do |config|
      config.developer_public_key = creds['developer_public_key']
      config.member_token = creds['member_token']
    end
    #@medium_client = Medium::Client.new(creds['medium_token'])
    #@medium_client = Medium::Client.new integration_token: creds['medium_token']
    @medium_client = MediumSdk.new integration_token: creds['medium_token']
  end

  desc 'showmarkdown [boardid]', 'Fetch trello board and render results in markdown.'
  def showmarkdown(board_id=nil)
    board = fetch_board(board_id)
    markdown = get_markdown_for_board(board)
    puts markdown
  end

  desc 'tomedium [boardid]', 'Fetch trello board and send results to Medium.'
  def tomedium(board_id=nil)
    board = fetch_board(board_id)
    markdown = get_markdown_for_board(board)
    data = @medium_client.post({
      title: "#{@@title_base} #{board.name.gsub(/#/,"")}",
      contentFormat: "markdown",
      content: markdown,
      tags: ["privacy", "news", "infosec", "security"],
      publishStatus: "draft",
      publicationId: "424d9e2d3917"
    })
    pp data

  end


  private
  def fetch_board(board_id=nil)
    if (!board_id)
      # pp Trello.client.find(:board, "eakDbSGm")
      # pp Trello.client.find(:board, "594ad5514ff9992f0910352c")
      boards = Trello::Board.all.keep_if {|v|
        v.organization_id == "594aaf5f1a6323f303e8e540" && v.name =~ /^\#/
      }.sort {|x,y| x.name <=> y.name}
      board_id = boards_menu(boards).id
      puts "Board ID: #{board_id}"
    end
    return Trello.client.find(:board, board_id)
  end

  def get_markdown_for_board(board)
    output = "# #{@@title_base} #{board.name.gsub(/#/,"")}\n## TK Subtitle\n_This is the Scrambled Bits weekly newsletter, a quick summary of the week’s most interesting news at the intersection of security, privacy, encryption, technology, and law._\n\n"

    board.lists.keep_if { |l| l.name != "TBD" }.each { |list|
      output << "# " + list.name + "\n"
      list.cards.each { |card|
        urlidx = card.attachments.index { |v| !v.is_upload }
        url = card.attachments[urlidx].url
        if (list.name == "Notable Vulnerabilities and Breaches" || list.name == "Bottom of the News")
          output << "* **[#{card.name}](#{url})**--#{card.desc}\n"
        else
          output << "## [#{card.name}](#{url})\n\n#{card.desc}\n\n"
          card.attachments.keep_if { |v| v.is_upload }.each { |a|
            output << "![](#{a.url})\n"
          }
        end
      }
    }
    output << "\n\n---\n_If you liked this, please click the 💚 below. If you’re reading this in an email, please go to the article on the web first. Liking the article will help other people see it on Medium. You might also be interested in [TK] last week’s summary compliments of [IronCore Labs](https://ironcorelabs.com/)._\n\n_[Subscribe to our email digest](https://blog.ironcorelabs.com/email-notifications-29f6934c9bb7#.d1k0dywpc) to avoid missing another update._"
    return output
  end

  def boards_menu(boards)
    puts "Choose a board:"
    boards.each_index { |num|
      puts num.to_s + ". " + boards[num].name
    }
    choice = STDIN.gets.strip.to_i
    case choice
    when 0..(boards.length-1)
      return boards[choice]
    else
      puts "Bad choice. Try again."
      return boards_menu(boards)
    end
  end

  def debug(msg)
    say '** '+msg, :blue, true unless !options[:debug]
  end
  def out(msg)
    say msg, :green, true
  end
  def error(msg)
    say '!! '+msg, :red, true
  end
end

Manager.start(ARGV)


