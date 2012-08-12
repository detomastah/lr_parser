class ParseState
	attr_accessor :rule, :position, :from_state, :redux
	
	def initialize(rule, position, from_state, redux = [])
		@rule = rule
		@position = position
		@from_state = from_state
		@redux = Array.new(redux)
	end

	def ==(other)
		@rule == other.rule && @position == other.position && @from_state == other.from_state
	end

	def inspect
		"(#{@rule[0].inspect} -> #{@rule[1].inspect}, #{@position}, #{@from_state})"
	end

	def parse_tree
		self.rule[2].call(self.redux)
	end
end

class Token
	attr_accessor :value
	attr_reader :name
	
	def initialize(name, value = nil)
		@name = name
		@value = value
	end

	def ==(other)
		if other.is_a?(String)
			other == @name
		else
			other.name == self.name
		end
	end
end

def is_terminal?(sym, grammar)
	for s in grammar
		return false if sym == s[0]
	end
	return true
end

class Parser
	def initialize(grammar, input, start_symbol = "S")
		@start_symbol = start_symbol
		@input = input
		@grammar = grammar
		@chart = Array.new(@input.length + 1)
		for i in 0..@input.length
			@chart[i] = Array.new
		end
	end

	def add_to_state(state_index, new_state)
		state = @chart[state_index].find {|s| s == new_state}
		if state
			return false
		else
			@chart[state_index] << new_state
			return true
		end
	end

	def shift(state, current_symbol)
		if  current_symbol == state.rule[1][state.position]
			ps = ParseState.new(state.rule, state.position + 1, state.from_state, state.redux)
			ps.redux << current_symbol
			return ps
		else
			return nil
		end
	end

	def closure(state, index)
		res = []
		sym = state.rule[1][state.position]
		@grammar.each_with_index do |r, i|
			if r[0] == sym
				ps = ParseState.new(r, 0, index, Array.new)
				res << ps
			end
		end
		res
	end
	
	def reduce(state)
		res = []
		red_sym = state.rule[0]
		states = @chart[state.from_state]
		states.each do |s|
			sym = s.rule[1][s.position]
			if sym == red_sym
				ps = ParseState.new(s.rule, s.position + 1, s.from_state, s.redux)
				res << ps
			end	
		end
		return res
	end

	def parse
		@grammar.each do |s|
			if s[0] == @start_symbol
				add_to_state(0, ParseState.new(s, 0, 0))
			end
		end

		for input_index in 0..@input.length
			change = true
			while change
				change = false
				for s in @chart[input_index]		
					next_sym = s.rule[1][s.position]
					if next_sym.nil?
						res = reduce(s)
						res.each do |r|
							sym = r.rule[0]
							change ||= add_to_state(input_index, r)
							if change
								r.redux << s
							end

							if sym == "S" && r.from_state == 0 && input_index == @input.length
								puts "PARSED"
								#process(r)
								change = false
								return r
							end
						end
					elsif next_sym && is_terminal?(next_sym, @grammar)
						res = shift(s, @input[input_index])
						change ||= add_to_state(input_index + 1, res) if res
					elsif next_sym
						res = closure(s, input_index)
						res.each do |r|
							change ||= add_to_state(input_index, r)
						end
					end
				end
				
				
			end
		end
	end
end


vars = {}

val_proc = lambda {|t| t[0].value }

G = [
	["S", ["STMTS"], lambda {|t| t[0].parse_tree }],
	["STMTS", [], lambda {|t| nil }],
	["STMTS", ["STMT", "STMTS"], lambda {|t| t[0].parse_tree; t[1].parse_tree }],
	["STMT", ["IDEN", "=", "EXP"], lambda {|t| vars[t[0].value] = t[2].parse_tree }],
	["STMT", ["F_IDEN", "EXP"], lambda {|t| send(t[0].value, t[1].parse_tree) }],
	["STMT", ["EXP"], lambda {|t| t[0].parse_tree }],
	["COND_EXP", ["EXP", "COMP_OP", "EXP"], lambda {|t| t[0].parse_tree.send(t[1].parse_tree, t[2].parse_tree) }],
	["STMT", ["WHILE", "COND_EXP", "STMTS", "END"], lambda {|t| while t[1].parse_tree; t[2].parse_tree; end  }],
	["EXP", ["INT"], val_proc],
	["EXP", ["IDEN"], lambda{|t| vars[t[0].value]} ],
	["OP", ["+"], lambda {|t| "+"}],
	["OP", ["*"], lambda {|t| "*"}],
	["COMP_OP", ["<"], lambda {|t| "<"}],
	["EXP", ["(", "EXP", ")"], lambda {|t| t[1].parse_tree}],
	["EXP", ["EXP", "OP", "EXP"], lambda {|t|
                                              t[0].parse_tree.send(t[1].parse_tree, t[2].parse_tree)
                                             }]
]

IN2 = [
	Token.new("IDEN", "x"), Token.new("="), Token.new("INT", 0),
	Token.new("WHILE"), Token.new("IDEN", "x"), Token.new("<"), Token.new("INT", 10),
	Token.new("IDEN", "x"), Token.new("="), Token.new("IDEN", "x"), Token.new("+"), Token.new("INT", 1),
	Token.new("F_IDEN", "puts"), Token.new("IDEN", "x"),
	Token.new("END")
     ]

p = Parser.new(G, IN2)
r = p.parse
r.parse_tree


