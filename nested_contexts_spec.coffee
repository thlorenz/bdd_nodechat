beforeEach -> @a = 0

describe 'whe i have an int', ->
  it 'assigns' , -> expect(@a).toEqual(0)

  describe 'and i increment by 1', ->
    beforeEach -> @a++
    it 'is 1', -> expect(@a).toEqual 1

    describe 'and i increment by 1 again', ->
      beforeEach -> @a++
      it 'is 2', -> expect(@a).toEqual 2

  describe 'and i increment by 2', ->
    beforeEach -> @a = @a + 2
    it 'is 2', -> expect(@a).toEqual 2
