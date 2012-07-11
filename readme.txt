
• to render yaml http://0.0.0.0:4567/simplest_layout.yaml or http://0.0.0.0:4567/simplest_layout
• hmmm, many haml pages wont render without help - is this right?
• http://0.0.0.0:4567/_second_partial.haml
• haml files begin with underscore

Refresher course
-----------------------------------------------------------------------------------------


@template window1

	@css wha/nona/formstuff1
	@css wha/nona/formstuff2
	
	@coffee blah/blahblah2
	@coffee blah/blahblah1
	
	@haml menubar
		{ home, you, explore, help }
		
	@haml splitview
	
		@haml 2colView
			@haml userInfo
				name: Steven
				location: london
				boos: 12
				
			@haml mainDetails
			
		@haml vertlist
			@haml facebooklist
			@haml followlist
				



-----------------------------------------------------------------------------------------
window1
-----------------------------------------------------------------------------------------

@coffee blah/blahblah1
@css wha/nona/formstuff2

head:
	title: hey there
body:
	h1: hello
	@yield
	


-----------------------------------------------------------------------------------------
REQUIREMENTS
-----------------------------------------------------------------------------------------

inline scss, coffeescript
scss, coffeescript dependencies
autowrapping text in span etc a la indesign
multiline text

	
yaml ? why
haml ? why

haml is for html
yaml is for composing haml (and maybe yaml?)
the yaml has to have values in to pass to the haml		
			